# ADR-0002: TEXT + CHECK вместо ENUM

**Статус:** принято, 2026-09-20

**Контекст и решение.** ENUM неудобен при удалении значений и в миграциях; CHECK меняется одной ALTER.

**Последствия.** Отражено в `db/schema.sql` v2.0; см. `docs/08_data_model.md`, `docs/10_kafka_events.md`, `docs/12_security.md`.
