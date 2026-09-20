# 10. События Kafka (v2.0)

| Топик | Партиции | Ключ | Ретенция | Продюсер |
|---|---|---|---|---|
| rentflow.invoice | 12 | invoice_id | 7 дней | Billing |
| rentflow.payment | 12 | invoice_id | 7 дней | Payments |
| rentflow.contract | 6 | contract_id | 7 дней | Contracts |
| rentflow.dlq | 1 | исходный ключ | 30 дней | консьюмеры |

Доставка **at-least-once**, порядок — в пределах ключа. События счёта и платежа делят ключ `invoice_id`, поэтому `PaymentConfirmed` не обгонит `InvoiceIssued` того же счёта.

## Публикация: outbox (ADR-0003)
Событие пишется в `outbox_event` в транзакции бизнес-операции. Relay (poll 1 с, батч 500) публикует `published_at IS NULL`, помечает; при ошибке `attempts++`, после 10 — алерт.

## Потребление: inbox
`INSERT INTO processed_event(consumer, event_id) ON CONFLICT DO NOTHING`; 0 строк — событие пропускается. Неразборчивое событие после 3 ретраев — в `rentflow.dlq` с заголовками `x-error`, `x-consumer`.

## Конверт v2
`event_id, event_type, schema_version, occurred_at, organization_id, topic, partition_key, payload` — `events/*.v2.json`. Добавление необязательных полей — та же версия; удаление/переименование — новая версия и параллельная публикация 30 дней.

| Событие | Топик | Когда | Консьюмеры |
|---|---|---|---|
| InvoiceIssued | rentflow.invoice | UC-02 | Notification |
| InvoiceOverdue | rentflow.invoice | overdue-job | Notification, Tasks |
| PaymentConfirmed | rentflow.payment | webhook succeeded | Notification, Tasks (закрыть follow-up при PAID) |
| PaymentRefunded | rentflow.payment | возврат | Notification |
| ContractStatusChanged | rentflow.contract | смена статуса договора | Tasks, Notification |
