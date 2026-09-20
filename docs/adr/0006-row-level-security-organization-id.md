# ADR-0006: Row Level Security по organization_id

**Статус:** принято, 2026-09-20

**Контекст и решение.** Защита от утечки между организациями независимо от WHERE в коде. Schema-per-tenant отклонён из-за стоимости миграций.

**Область.** Политика `organization_id = nullif(current_setting('app.current_org', true), '')::uuid` + `FORCE ROW LEVEL SECURITY` навешивается на все таблицы с `organization_id`: бизнес-таблицы (`tenant`, `user_account`, `property`, `contract`, `invoice`, `invoice_line`, `penalty`, `payment`, `task`, `notification`), а также на `outbox_event` (события до публикации изолированы по организации) и `audit_log`. Вне RLS — `organization` и `processed_event` (инбокс, без `organization_id`).

**Последствия.** Отражено в `db/schema.sql` v2.0; см. `docs/08_data_model.md`, `docs/10_kafka_events.md`, `docs/12_security.md`.
