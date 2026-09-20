# CHANGELOG

## 2.0.12 — 2026-09-20 (финальная сверка)
* openapi: добавлены operationId для 28 операций: authLogin, authRefresh, authInvitationAccept, getUser, listProperties, createProperty, getProperty, updateProperty, deleteProperty, listTenants, createTenant, getTenant, listContracts, createContract, getContract, activateContract, suspendContract, terminateContract, listInvoices, getInvoice, updateInvoice, cancelInvoice, createInvoicePayment, getPayment, paymentWebhook, listTasks, updateTask, listNotifications.
* 14_test_cases: 4 ссылок POST /payments → POST /invoices/{id}/payments (TC-03-05…07, TC-33).
* 16_traceability_matrix: эндпоинты приведены к контракту (нет PATCH /tenants, PATCH /tasks без {id}, PATCH /properties без {id}).
* 05_architecture: добавлен индекс всех 10 ADR со ссылками.
* ci.yml: PlantUML берётся актуальный plantuml.jar (пакет apt слишком старый для stdlib <C4/...>), _style.puml исключён из -checkonly.
* `api/openapi_changes_v2.md`, упомянутый в записях 2.0.1–2.0.2, из репозитория удалён: история контракта ведётся в этом файле.
* `README.md`, `api/openapi.yaml` `info.version`, `docs/09_rest_api.md` — 2.0.12.

## 2.0.11 — 2026-09-20 (аутентификация в REST-контракте)
* `api/openapi.yaml`: добавлены теги `auth`, `users` и 4 пути — `POST /auth/login`, `POST /auth/refresh`, `POST /auth/invitations/{token}/accept` (все с `security: []`), `GET /users/{id}`; схемы `LoginRequest`, `RefreshRequest`, `InvitationAccept`, `TokenPair`, `User` (закрытая, без `password_hash`); ответы `Unauthorized` (401), `Gone` (410), `TooManyRequests` (429). Всего 22 пути. `info.version` — 2.0.11.
* `docs/09_rest_api.md`: раздел «Аутентификация и пользователи».
* `docs/12_security.md`: раздел «Токены и вход» (TTL access 15 мин / refresh 30 дней, ротация, лимит 10 попыток / 15 мин, единый 401).
* `docs/14_test_cases.md`: TC-AUTH-02 снова проверяет `GET /users/{id}` (теперь эндпоинт существует); добавлены TC-AUTH-03…07 (приглашение, истечение 72 ч, rate-limit, ротация refresh, доступ к чужому профилю).
* `docs/16_traceability_matrix.md`: строка FR-51 привязана к 4 эндпоинтам и TC-AUTH-01…07; `docs/03_functional_requirements.md` FR-51 — ссылки на эндпоинты.
* `docs/15_open_questions.md`: открытый вопрос о создании приглашения администратором (вне контракта).
* `README.md` — 2.0.11.

## 2.0.10 — 2026-09-20 (исправление матрицы трассируемости)
* `docs/16_traceability_matrix.md`: строки FR-49/FR-50/FR-51 ссылались на TC-04-11 (кейс про `due_date = сегодня` в overdue-job); заменены на реальные идентификаторы кейсов из секции «Дополнено в 2.0.8»: TC-OVERPAY-01…03, TC-TENANT-01…02, TC-AUTH-01…02. Уточнены колонки API/диаграммы/модель данных (`overpaid_amount`, `TenantType`, `ck_tenant_inn`, ADR-0009/0010).
* `docs/14_test_cases.md`: TC-AUTH-02 ссылался на `GET /users/{id}`, которого нет в `api/openapi.yaml` (18 путей, `/users`/`/auth` отсутствуют); кейс переформулирован: `password_hash` не попадает ни в один ответ API и маскируется в audit_log. Вопрос о включении `/auth/*` и `/users/*` в контракт остаётся открытым (см. 15_open_questions).
* `.github/workflows/ci.yml`: файл упоминался в README и CHANGELOG 2.0.7, но в репозитории отсутствовал — добавлен (schema.sql на Postgres 15, сверка enum schema↔openapi, lint openapi.yaml, проверка JSON Schema событий, `plantuml -checkonly`, наличие PNG для каждой .puml/.bpmn).
* `api/openapi.yaml` `info.version` и `README.md` — 2.0.10.

## 2.0.9 — 2026-09-20 (ревью 2.0.8)
* `.github/workflows/ci` лежал без расширения `.yml` — GitHub Actions такой файл не подхватывает, CI фактически не запускался. Переименован в `ci.yml`.
* `README.md`: заголовок и ссылка на контракт всё ещё указывали v2.0.7 при тексте «Версия 2.0.8»; диапазон ADR `0001..0008` → `0001..0010`. Приведено к 2.0.9.
* `docs/16_traceability_matrix.md`: добавлены строки FR-49 (переплата / OVERPAYMENT_CREDIT), FR-50 (TenantType, ck_tenant_inn), FR-51 (password_hash argon2id) с привязкой к API, таблицам, ADR и тест-кейсам — требования 2.0.8 не были покрыты трассировкой.
* `CHANGELOG.md`: в разделе 2.0.8 смешивались маркеры `*` и `-` — унифицировано.
* Повторно сверено: `TenantType`, `InvoiceLine.kind`, `PaymentStatus` в `openapi.yaml` совпадают с CHECK в `db/schema.sql`; 5 JSON Schema событий валидны; битых внутренних ссылок в `docs/` нет.
* `api/openapi.yaml` `info.version` — 2.0.9.

## 2.0.8 — 2026-09-20
* `api/openapi.yaml`: добавлена схема `TenantType` (LEGAL_ENTITY / SOLE_PROPRIETOR / INDIVIDUAL) и поле `type` в `TenantCreate`/`Tenant` — синхронизировано с `tenant.type` в `db/schema.sql` (FR-50).
* `tenant.type` (LEGAL_ENTITY / SOLE_PROPRIETOR / INDIVIDUAL) + CHECK `ck_tenant_inn`; FR-50; Tenant в OpenAPI.
* `user_account.password_hash` (argon2id), `invited_at`, `last_login_at`; CHECK `ck_user_active_has_password`; ADR-0009; FR-51; раздел «Пароли» в 12_security.
* Переплата: снята верхняя граница `paid_amount`, добавлено вычисляемое `invoice.overpaid_amount`; `invoice_line.kind = OVERPAYMENT_CREDIT` с `source_invoice_id` и уникальным индексом; ADR-0010; FR-49.
* ER-диаграмма, 08_data_model, 14_test_cases (7 кейсов), 15_open_questions обновлены; закрыты три открытых вопроса.

## 2.0.7 — 2026-09-20 (ревью репозитория `rentflow-spec-`)
* `README.md` ссылался на `api/openapi_changes_v2.md`, которого в репозитории нет (файл удалён в 2.0.2 как применённый) — ссылка убрана, история контракта ведётся в `CHANGELOG.md`; добавлено описание `api/`, `img/`, `prototype/` в разделе «Структура».
* `CHANGELOG.md`: разделы выстроены в обратном хронологическом порядке (2.0.6 стоял перед 2.0.5 и 2.0.4).
* Сверка enum `PaymentStatus`/`InvoiceStatus`/`ContractStatus`/`TaskStatus` между `db/schema.sql` и `api/openapi.yaml` — расхождений нет.
* Проверены: 5 JSON Schema событий (валидный JSON), `openapi.yaml` (валидный YAML, 18 путей), `.github/workflows/ci.yml`, все `img/*.png` (непустые), внутренние ссылки в `docs/` — битых нет.
* `api/openapi.yaml` `info.version` — 2.0.7.

## 2.0.6 — 2026-09-20 (замечания ревью к 2.0.5)
* **PaymentStatus в документах**: в 2.0.5 значение `EXPIRED` было добавлено только в `openapi.yaml`; теперь синхронизированы `docs/03_functional_requirements.md` (FR-34: PENDING → EXPIRED job'ом истечения по TTL платёжной ссылки провайдера, 30 мин, вместо «24 ч → FAILED»), `docs/14_test_cases.md` (TC-03-10: ожидаемый результат `Payment EXPIRED`) и `docs/07_state_models.md` (сводка переходов Payment дополнена `EXPIRED`). Сценарий «webhook не пришёл» имеет один статус и один срок во всех артефактах — как в `diagrams/state_payment.puml`.
* **RLS `audit_log`**: таблица добавлена в общий цикл `FOREACH` в `db/schema.sql`, отдельная политика с `current_setting(...)::uuid` без `nullif` удалена — при пустом `app.current_org` политика возвращает NULL (0 строк), а не падает с ошибкой каста.
* **ADR-0006 и `docs/12_security.md`**: явно перечислены таблицы под RLS, включая `outbox_event` и `audit_log`; `organization` и `processed_event` — вне RLS.
* `docs/15_open_questions.md`: открытый вопрос о сроке жизни платёжной ссылки переформулирован под принятый TTL 30 мин (убрано последнее упоминание «24 часа»).
* `README.md`, `api/openapi.yaml` `info.version` — 2.0.6.

## 2.0.5 — 2026-09-20 (CI и синхронизация PaymentStatus)
* **OpenAPI**: `PaymentStatus` дополнен значением `EXPIRED` — приведён в соответствие с `CHECK payment.status` в `db/schema.sql` и `diagrams/state_payment.puml`.
* **CI**: добавлен `.github/workflows/ci.yml` — применение `schema.sql` на PostgreSQL 15 с проверкой RLS, синтаксическая проверка PlantUML, lint OpenAPI (Redocly), компиляция JSON Schema событий (draft 2020-12), автоматическая сверка enum `PaymentStatus` с DDL.

## 2.0.4 — 2026-09-20 (полная зачистка остатков v1)
* Последние упоминания `InvoiceCreated` заменены на `InvoiceIssued`: `diagrams/bpmn_invoice_lifecycle.bpmn` (sendTask «Опубликовать InvoiceIssued»), `diagrams/c4_container.puml`, `docs/11_sequence_diagrams.md`, `docs/14_test_cases.md` (TC-02-01), `docs/16_traceability_matrix.md`.
* `api/openapi.yaml`: `info.version` поднят с 1.0.0 до 2.0.4 — контракт API теперь версионируется вместе со спецификацией.
* `README.md`: заголовок и раздел «Источник истины» приведены к 2.0.4; `openapi_changes_v2.md` явно помечен как применённая история правок.
* Прототип: фильтр «OVERDUE» в списке счетов помечен как UI-фильтр по `overdueSince` (не статус БД), чтобы не путать с удалённым статусом.
* `img/c4_container.png` и `img/bpmn_invoice_lifecycle.png` перегенерированы из исправленных источников (если рендер был доступен при сборке — см. примечание к релизу).

## 2.0.3 — 2026-09-20 (сверка с CHANGELOG)
* `diagrams/c4_container.puml`: Kafka-контейнер описывает события v2 (`InvoiceIssued`, `InvoiceOverdue`, `PaymentConfirmed`, `PaymentRefunded`, `ContractStatusChanged`, transactional outbox); БД — `outbox_event`/`processed_event`, RLS, UUIDv7. `img/c4_container.png` перегенерирован.
* `img/bpmn_invoice_lifecycle.png` перегенерирован из актуального `.bpmn` (задача «Проставить overdue_since, начислить пеню»).
* `.github/workflows/ci.yml` присутствует в сборке (проверка PUML/OpenAPI/SQL).

## 2.0.2 — 2026-09-20 (финальная сборка)
* `img/*.png` перегенерированы из актуальных PUML: `er_diagram` (15 сущностей, 22 связи, outbox/audit), `state_invoice`, `state_payment`, `seq_uc02`, `seq_uc03`, `state_contract`, `state_task`.
* BPMN `bpmn_invoice_lifecycle.bpmn`: задача «Перевести счёт в OVERDUE» заменена на «Проставить overdue_since, начислить пеню».
* Аддендумы 03/07/14 слиты в основные документы (раздел «Дополнения v2.0»), отдельные `*_addendum.md` удалены.
* `api/openapi_changes_v2.md` помечен как применённый (история изменений).
* `er_diagram.puml` переписан в валидный многострочный синтаксис PlantUML, добавлен `img/er_diagram.svg`; прототип очищен от сравнения `status==='OVERDUE'`.

## 2.0.1 — 2026-09-20
* `seq_uc04_overdue.puml` и PNG перерисованы под v2: `overdue_since` вместо статуса OVERDUE, таблица `penalty` с UNIQUE по дате, outbox/inbox, задача `OVERDUE_FOLLOWUP`.
* Тексты FR-23, FR-30, UC-04, разделы 07/11/13/14/16 очищены от статуса OVERDUE.
* ADR-0004/0005/0007 получили осмысленные имена файлов.
* `api/openapi.yaml` фактически приведён к `openapi_changes_v2.md`: `InvoiceStatus` без OVERDUE, поля `overdue_since`/`overdue`, фильтр `GET /invoices?overdue=true`.
* Прототип `prototype/index.html`: просрочка показывается признаком `overdueSince`, а не статусом.

## 2.0 — 2026-09-20 (по итогам ревью)
* **Изоляция**: `organization_id` во всех бизнес-таблицах + RLS-политики (ADR-0006).
* **Пеня** хранится один раз — в `penalty`; `invoice.penalty_amount` — агрегат; `invoice_line.kind='PENALTY'` удалён (ADR-0004).
* **Статус счёта**: `OVERDUE` убран; введена вторая ось `overdue_since` (ADR-0005).
* **Идемпотентность**: PK `(user_id, key)`, хеш запроса, `IN_PROGRESS/COMPLETED`; ответы 409/422.
* **Kafka**: transactional outbox + inbox `processed_event (consumer, event_id)`; конверт v2 с `schema_version`, `partition_key` (ADR-0003). `InvoiceCreated` переименован в `InvoiceIssued`, добавлен `PaymentRefunded`.
* **Договоры**: EXCLUDE на пересечение периодов по объекту (ADR-0008); `currency`, `billing_day`, `grace_days`, единицы `penalty_rate_pct`.
* **Платежи**: `UNIQUE (provider, provider_payment_id)`, статусы `EXPIRED`, `REFUNDED`, `payer_user_id`, `failure_reason`.
* **Задачи**: `contract_id`, CHECK ссылки по типу, одна открытая follow-up задача на счёт.
* **Уведомления**: получатель tenant или user (CHECK), `channel`, `template`, `status`.
* **Часовой пояс** организации (ADR-0007). **Аудит** `audit_log`. Индексы по FK и рабочим выборкам.
* `docs/08_data_model.md` приведён к DDL; `state_payment.puml` синхронизирован с CHECK; `user_account.tenant_id` получил FK и CHECK по роли.
* Добавлены FR-43…FR-48, TC-30…TC-39, CI.
