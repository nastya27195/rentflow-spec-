# 12. Безопасность (v2.0)

## Аутентификация и изоляция
JWT RS256 (15 мин) + refresh (7 дней); в токене `sub, org, role, tenant_id?`. В начале транзакции: `SET LOCAL app.current_org = :org; SET LOCAL app.current_user = :sub`. Все бизнес-таблицы под `FORCE ROW LEVEL SECURITY`, приложение — не суперпользователь. Под той же политикой — `outbox_event` (у него есть `organization_id`) и `audit_log`; `processed_event` и `organization` — вне RLS (ADR-0006). Роль TENANT дополнительно ограничена фильтром `tenant_id = token.tenant_id` в сервисном слое. Чужой id -> 404, не 403.

## Идемпотентность POST
`Idempotency-Key` (UUID) обязателен для `POST /payments`, `/invoices`, `/contracts`. Ключ уникален в разрезе пользователя — `PK (user_id, key)`. INSERT `IN_PROGRESS` с `request_hash = sha256(body)`; при конфликте: `IN_PROGRESS` -> **409** `request_in_progress`; другой hash -> **422** `idempotency_key_reused`; иначе сохранённый ответ. TTL 24 ч.

## Webhook провайдера
`X-Signature = HMAC-SHA256(secret, raw_body)` по сырому телу до парсинга, сравнение constant-time; `X-Timestamp` — окно ±5 мин. Дубль по `(provider, provider_payment_id)` -> 200 без побочных эффектов. Два активных секрета, ротация 90 дней.

## Прочее
Rate limit 100 rps на организацию, 10 rps на `POST /payments` на пользователя. `audit_log` append-only. Маскирование `email`, `phone` в логах. Деактивация менеджера: отзыв токенов, переназначение открытых задач ADMIN (FR-47).

## Пароли (2.0.8)

Хранится только `password_hash` (argon2id, m=64 MiB, t=3, p=1). Поле исключено из ответов API и маскируется в `audit_log`. Смена пароля инвалидирует refresh-токены пользователя. Приглашение — одноразовая ссылка с TTL 72 ч (`POST /auth/invitations/{token}/accept`). См. ADR-0009.

## Токены и вход (2.0.11)

`POST /auth/login` выдаёт access JWT (TTL 15 мин) и одноразовый refresh-токен (TTL 30 дней); `POST /auth/refresh` ротирует пару, повторное использование refresh-токена отзывает всю цепочку. Лимит входа — 10 неудачных попыток за 15 мин на e-mail и IP (429). Ответы `/auth/*` не различают «пользователь не найден» и «неверный пароль» (единый 401 `INVALID_CREDENTIALS`). `GET /users/{id}` — единственный эндпоинт, возвращающий `user_account`; его схема `User` закрыта и не содержит `password_hash`.