# Тест-кейсы ключевых сценариев

Тест-кейсы покрывают UC-02, UC-03 и UC-04. Приоритет: H — блокирующий для релиза, M — важный, L — желательный.

## UC-02. Автоматическое начисление платежа
| ID | Предусловие | Шаги | Ожидаемый результат | Приоритет |
|---|---|---|---|---|
| TC-02-01 | Договор ACTIVE, next_billing_date = сегодня | Запуск billing-job в 00:05 | Создан счёт ISSUED на rent_amount, due_date = сегодня + grace_days, next_billing_date сдвинута на месяц, событие InvoiceIssued | H |
| TC-02-02 | Счёт за период уже существует | Повторный запуск job за ту же дату | Дубликат не создан, в лог записано «skipped» | H |
| TC-02-03 | Договор SUSPENDED | Запуск job | Счёт не создан | H |
| TC-02-04 | Договор EXPIRED / TERMINATED | Запуск job | Счёт не создан | M |
| TC-02-05 | next_billing_date в будущем | Запуск job | Счёт не создан, дата не изменена | M |
| TC-02-06 | 10 000 активных договоров | Запуск job | Все счета созданы ≤ 10 мин (NFR-03) | M |
| TC-02-07 | Ошибка БД при создании одного счёта | Запуск job | Остальные счета созданы, ошибочный договор в отчёте job, повтор создаёт пропущенный счёт | M |
| TC-02-08 | Договор ACTIVE, billing_day = 31, месяц с 30 днями | Запуск job | Счёт создан в последний день месяца | L |

## UC-03. Оплата счёта через платёжный шлюз
| ID | Предусловие | Шаги | Ожидаемый результат | Приоритет |
|---|---|---|---|---|
| TC-03-01 | Счёт ISSUED, арендатор аутентифицирован | POST /invoices/{id}/payments на полную сумму; webhook success | 201, Payment PENDING → CONFIRMED, счёт PAID, событие PaymentConfirmed | H |
| TC-03-02 | Тот же Idempotency-Key и тело | Повторный POST | 200, тот же payment_id, второй платёж не создан | H |
| TC-03-03 | Webhook с невалидной подписью | Отправка webhook | 401, платёж остаётся PENDING | H |
| TC-03-04 | Счёт ISSUED, сумма меньше долга | Оплата части; webhook success | Счёт PARTIALLY_PAID, paid_amount увеличен | H |
| TC-03-05 | Сумма больше остатка долга | POST /invoices/{id}/payments | 422 VALIDATION_ERROR, платёж не создан | H |
| TC-03-06 | Счёт PAID или CANCELLED | POST /invoices/{id}/payments | 409 INVALID_STATE | M |
| TC-03-07 | Счёт другого арендатора | POST /invoices/{id}/payments | 403 FORBIDDEN | H |
| TC-03-08 | Webhook fail от шлюза | Отправка webhook | Payment FAILED, счёт не изменён, уведомление арендатору | M |
| TC-03-09 | Повторный webhook с тем же provider_payment_id | Отправка webhook дважды | 200, состояние платежа не изменилось, одно событие PaymentConfirmed | H |
| TC-03-10 | Платёж PENDING, TTL платёжной ссылки провайдера (30 мин) истёк, webhook не пришёл | Запуск job истечения | Payment EXPIRED, счёт доступен для новой оплаты | M |

## UC-04. Обработка просрочки и начисление пени
| ID | Предусловие | Шаги | Ожидаемый результат | Приоритет |
|---|---|---|---|---|
| TC-04-01 | Счёт ISSUED, due_date < сегодня | Запуск overdue-job | У счёта проставлен overdue_since = today, статус ISSUED не изменён, событие InvoiceOverdue, уведомление арендатору | H |
| TC-04-02 | Счёт с overdue_since, penalty_rate_pct = 0,1 | Запуск job на следующий день | Начислена пеня = остаток × 0,001, создана запись penalty за дату, invoice.penalty_amount пересчитан | H |
| TC-04-03 | Счёт PARTIALLY_PAID, due_date < сегодня | Запуск job | overdue_since проставлен, статус PARTIALLY_PAID сохранён, пеня от остатка долга | H |
| TC-04-04 | Счёт с overdue_since, пеня за сегодня уже начислена | Повторный запуск job | Пеня не дублируется | H |
| TC-04-05 | Просроченный счёт | Первое событие InvoiceOverdue | Создана задача OVERDUE_FOLLOWUP менеджеру NEW со ссылкой на счёт | H |
| TC-04-06 | Просроченный счёт, открытая задача уже есть | Повторное событие | Вторая задача не создаётся | M |
| TC-04-07 | Просроченный счёт | Полная оплата долга и пени | Счёт PAID, overdue_since сброшен, начисление пени прекращено, задача закрыта автоматически | H |
| TC-04-08 | Счёт PAID / CANCELLED, due_date < сегодня | Запуск job | Статус не меняется, пеня не начисляется | M |
| TC-04-09 | penalty_rate = 0 в договоре | Запуск job | overdue_since проставлен, пеня не начисляется, задача создана | M |
| TC-04-10 | overdue_since старше 30 дней | Запуск job | Пеня продолжает начисляться, задача эскалирована (приоритет HIGH) | L |
| TC-04-11 | due_date = сегодня | Запуск job | Счёт остаётся ISSUED (просрочка со следующего дня) | M |

## Дополнения v2.0


| ID | Сценарий | Ожидание |
|---|---|---|
| TC-30 | Повторный webhook с тем же provider_payment_id | 200, paid_amount не изменился |
| TC-31 | Webhook с невалидной подписью | 401, security-лог, платёж не изменён |
| TC-32 | Webhook с X-Timestamp старше 5 мин | 401 `stale_request` |
| TC-33 | POST /invoices/{id}/payments amount > остаток | 422 `amount_exceeds_outstanding` |
| TC-34 | Два billing-job параллельно | один счёт (UNIQUE + SKIP LOCKED) |
| TC-35 | Тот же Idempotency-Key, другое тело | 422 `idempotency_key_reused` |
| TC-36 | Активация договора с пересечением периода | 409 `property_period_conflict` |
| TC-37 | Менеджер org A запрашивает счёт org B | 404 (RLS) |
| TC-38 | Возврат по PAID-счёту | PARTIALLY_PAID, penalty не изменён, PaymentRefunded |
| TC-39 | Пользователь TENANT без tenant_id | отклонено CHECK ck_user_tenant_role |

## Дополнено в 2.0.8

| ID | Сценарий | Ожидание |
|---|---|---|
| TC-OVERPAY-01 | Webhook CONFIRMED на сумму больше остатка | Платёж CONFIRMED, счёт PAID, `overpaid_amount` = излишек |
| TC-OVERPAY-02 | Следующий счёт по договору с переплатой | Строка OVERPAYMENT_CREDIT (amount < 0, `source_invoice_id`); повторный запуск job не создаёт вторую |
| TC-OVERPAY-03 | Переплата по договору TERMINATED | Задача MANUAL «Вернуть переплату», строка зачёта не создаётся |
| TC-TENANT-01 | LEGAL_ENTITY без ИНН | 422 VALIDATION_ERROR |
| TC-TENANT-02 | INDIVIDUAL без ИНН | 201 |
| TC-AUTH-01 | Активация пользователя без пароля и приглашения | Ошибка ck_user_active_has_password |
| TC-AUTH-02 | `GET /users/{id}` для пользователя с заданным паролем; для контроля — ответ `assignee` в задачах и запись audit_log по user_account | В теле ответа `User` нет поля `password_hash` (схема закрыта, `additionalProperties: false`); в audit_log значение маскировано `***` |
| TC-AUTH-03 | `POST /auth/invitations/{token}/accept` с валидным токеном и паролем ≥ 12 символов | 200, `TokenPair`; `password_hash` заполнен (argon2id), `is_active = true`; повтор с тем же токеном — 410 |
| TC-AUTH-04 | `POST /auth/invitations/{token}/accept` спустя > 72 ч после `invited_at` | 410 `INVITATION_EXPIRED`, `password_hash` остаётся NULL |
| TC-AUTH-05 | `POST /auth/login` с неверным паролем 10 раз за 15 мин, затем с верным | Первые 10 — 401 `INVALID_CREDENTIALS`, 11-й — 429; в логах пароль отсутствует |
| TC-AUTH-06 | `POST /auth/refresh` дважды с одним refresh-токеном | Первый — 200, новая пара; второй — 401 и отзыв всей цепочки токенов пользователя |
| TC-AUTH-07 | `GET /users/{id}` менеджером для чужого id | 403; ADMIN своей организации — 200; id из другой организации — 404 (RLS) |
