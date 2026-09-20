# 08. Модель данных (v2.0)

Источник истины — `db/schema.sql`. Документ объясняет **зачем**, DDL — **как**.

## Принципы
1. **Мультитенантность.** `organization_id` в каждой бизнес-таблице, защищён RLS (`app.current_org`).
2. **Один источник истины на факт.** Пеня — `penalty`; строки — `invoice_line`; оплата — `payment`. `invoice.amount / penalty_amount / paid_amount` — агрегаты, пересчитываемые `fn_invoice_recalc`. Приложение их не пишет.
3. **Две оси состояния счёта.** `status` — оплата (DRAFT/ISSUED/PARTIALLY_PAID/PAID/CANCELLED); `overdue_since` — срок.
4. **Ключи.** UUID v7 генерирует приложение (ADR-0001). Перечисления — TEXT + CHECK (ADR-0002).
5. **Время.** `TIMESTAMPTZ` для событий, `DATE` для биллинга в `organization.timezone` (ADR-0007).

## Сущности
| Таблица | Назначение | Ключевые правила |
|---|---|---|
| organization | арендодатель | timezone |
| tenant | арендатор | — |
| user_account | учётная запись | `role=TENANT` <=> `tenant_id IS NOT NULL` |
| property | объект аренды | area_sqm > 0 |
| contract | договор | end > start; EXCLUDE по (объект, период) для ACTIVE/SUSPENDED; billing_day 1..28 |
| invoice | счёт | UNIQUE(contract, period_start); paid <= amount+penalty; PAID => оплачен полностью |
| invoice_line | строки счёта | kind RENT/ADJUSTMENT |
| penalty | пеня за день | UNIQUE(invoice, accrual_date) |
| payment | платёж | UNIQUE(provider, provider_payment_id); FAILED => failure_reason |
| idempotency_key | ключи POST | PK(user_id, key); request_hash; TTL 24 ч |
| task | задача менеджера | тип определяет обязательную ссылку; одна открытая OVERDUE_FOLLOWUP на счёт |
| notification | уведомление | получатель tenant или user; PUSH только user |
| outbox_event | исходящие события | публикует Relay по created_at |
| processed_event | inbox консьюмеров | PK(consumer, event_id) |
| audit_log | аудит contract/invoice/payment | changed_by из `app.current_user` |

## Инварианты и кто их обеспечивает
| Инвариант | Механизм | Где |
|---|---|---|
| Один счёт на договор и период | UNIQUE | schema.sql |
| Пеня за день один раз | UNIQUE(invoice_id, accrual_date) | schema.sql |
| Договоры по объекту не пересекаются | EXCLUDE gist | ADR-0008 |
| Агрегаты счёта = суммам деталей | триггеры recalc_on_* | ADR-0004 |
| Событие обработано один раз | processed_event PK | docs/10 |
| Нет доступа к чужой организации | RLS | ADR-0006, docs/12 |
| Повтор POST не создаёт второй платёж | idempotency_key PK + request_hash | docs/12 |
| Дубль webhook не удваивает оплату | UNIQUE(provider, provider_payment_id) | schema.sql |
| Одна открытая follow-up задача на счёт | частичный UNIQUE-индекс | schema.sql |

## Расчёт пени
`penalty.amount = round((amount - оплаченная часть аренды) * penalty_rate_pct / 100, 2)` за каждый день с `due_date + grace_days + 1` до полной оплаты. Ставка — **% в день**. Пеня на пеню не начисляется.

Диаграмма: `diagrams/er_diagram.puml` → `img/er_diagram.png` / `img/er_diagram.svg`.

## Изменения 2.0.8

`tenant.type` — LEGAL_ENTITY / SOLE_PROPRIETOR / INDIVIDUAL, CHECK `ck_tenant_inn`. `user_account.password_hash`, `invited_at`, `last_login_at` — ADR-0009. `invoice.overpaid_amount` — STORED generated column, верхняя граница `paid_amount` снята; `invoice_line.kind` расширен значением `OVERPAYMENT_CREDIT` (amount < 0, `source_invoice_id` уникален) — ADR-0010, FR-49.

| Инвариант | Механизм | Артефакт |
|---|---|---|
| ИНН обязателен для юрлиц и ИП | CHECK ck_tenant_inn | schema.sql |
| Активный пользователь имеет пароль или открытое приглашение | CHECK ck_user_active_has_password | schema.sql |
| Переплата зачитывается один раз | UNIQUE uq_invoice_line_overpay_source | schema.sql |
| Строка OVERPAYMENT_CREDIT отрицательная, остальные — нет | CHECK ck_invoice_line_sign | schema.sql |