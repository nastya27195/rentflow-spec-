# ADR-0003: Transactional outbox для Kafka

**Статус:** принято, 2026-09-20

**Контекст и решение.** Публикация после COMMIT теряет события при падении между COMMIT и produce. Outbox + Relay = at-least-once без потерь; дубли гасит inbox.

**Последствия.** Отражено в `db/schema.sql` v2.0; см. `docs/08_data_model.md`, `docs/10_kafka_events.md`, `docs/12_security.md`.
