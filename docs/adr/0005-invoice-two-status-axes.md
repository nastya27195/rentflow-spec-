# ADR-0005: Две оси статуса счёта

**Статус:** принято, 2026-09-20

**Контекст и решение.** OVERDUE конфликтовал с PARTIALLY_PAID. Ось оплаты — status, ось срока — overdue_since; в API поле overdue:boolean.

**Последствия.** Отражено в `db/schema.sql` v2.0; см. `docs/08_data_model.md`, `docs/10_kafka_events.md`, `docs/12_security.md`.
