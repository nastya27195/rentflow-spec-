# ADR-0004: Агрегаты счёта через триггер

**Статус:** принято, 2026-09-20

**Контекст и решение.** amount/penalty_amount/paid_amount нужны в каждом списке; SUM по трём таблицам на запрос дорог. Единая fn_invoice_recalc исключает рассинхронизацию.

**Последствия.** Отражено в `db/schema.sql` v2.0; см. `docs/08_data_model.md`, `docs/10_kafka_events.md`, `docs/12_security.md`.
