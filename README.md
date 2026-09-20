# RentFlow — спецификация системы управления арендой (v2.0.12)

Версия 2.0.12 — финальная сборка после ревью тим-лида команды СА (2026-09-20). Закрытые замечания — в `CHANGELOG.md`.

## Источник истины
* Структура данных — **`db/schema.sql`** (PostgreSQL 15). `diagrams/er_diagram.puml` — производный артефакт.
* Контракт API — `api/openapi.yaml` v2.0.12 (история правок контракта — в `CHANGELOG.md`).
* Контракт событий — `events/*.v2.json` (JSON Schema, конверт v2).
* Архитектурные решения — `docs/adr/`.

## Структура
```
db/schema.sql            DDL: таблицы, инварианты, триггеры агрегатов, RLS, аудит
diagrams/                PlantUML: ER, состояния, последовательности (outbox), C4, BPMN
docs/00..16_*.md         глоссарий, требования, модели, безопасность, тест-кейсы, трассировка
docs/adr/0001..0010      ADR
events/*.v2.json         схемы событий Kafka
.github/workflows/ci.yml прогон schema.sql на Postgres 15, проверка PlantUML и JSON Schema
```

## Структура репозитория (полная)
```
api/openapi.yaml         контракт REST API (OpenAPI 3.0.3)
img/*.png, er_diagram.svg  отрендеренные диаграммы из diagrams/
prototype/index.html     кликабельный прототип UI (без сборки, открыть в браузере)
CHANGELOG.md             история версий спецификации
```

## Локальная проверка
```
docker run --rm -e POSTGRES_PASSWORD=x -d --name pg -p 5432:5432 postgres:15
psql postgresql://postgres:x@localhost/postgres -v ON_ERROR_STOP=1 -f db/schema.sql
```
