# Матрица трассируемости требований

Матрица связывает функциональные требования с бизнес-сценариями, API, диаграммами, элементами модели данных и тест-кейсами.

| Требования | Use case | API / интеграция | Диаграммы | Модель данных | Тесты |
|---|---|---|---|---|---|
| FR-01–FR-03 | UC-01 | GET/POST /properties, PATCH /properties/{id}, GET/POST /tenants | c4_container, er_diagram | property, tenant | — |
| FR-10–FR-14 | UC-01, UC-06 | POST /contracts, POST /contracts/{id}/activate, /terminate | state_contract | contract | — |
| FR-20, FR-21, FR-22 | UC-02 | — (cron 00:05), Kafka InvoiceIssued | seq_uc02_billing, state_invoice, bpmn_invoice_lifecycle | invoice, invoice_line | TC-02-01…08 |
| FR-25 | UC-05 | PATCH /invoices/{id}, POST /invoices/{id}/cancel | state_invoice | invoice, invoice_line | — |
| FR-30–FR-34 | UC-03 | POST /invoices/{id}/payments, POST /webhooks/payment, Kafka PaymentConfirmed | seq_uc03_payment, state_payment | payment, idempotency_key | TC-03-01…10 |
| FR-23, FR-24, FR-41, FR-42 | UC-04 | GET /invoices?overdue=true, GET /tasks, PATCH /tasks/{id}, Kafka InvoiceOverdue | seq_uc04_overdue, state_task | penalty, task | TC-04-01…11 |
| FR-40 | UC-02, UC-03, UC-04 | Kafka → Notification | c4_container | notification | TC-03-08, TC-04-01 |
| NFR-05, NFR-08 | все | Idempotency-Key, HMAC webhook, processed_event | seq_uc03_payment | idempotency_key, processed_event | TC-03-02, TC-03-03, TC-03-09 |
| FR-49 | UC-03 | POST /webhooks/payment, GET /invoices/{id} (`overpaid_amount`) | seq_uc03_payment, state_invoice | invoice, invoice_line (kind=OVERPAYMENT_CREDIT), ADR-0010 | TC-OVERPAY-01, TC-OVERPAY-02, TC-OVERPAY-03 |
| FR-50 | UC-01 | POST /tenants (`TenantType`) | er_diagram | tenant (CHECK ck_tenant_inn) | TC-TENANT-01, TC-TENANT-02 |
| FR-51 | UC-AUTH (вход/приглашение) | POST /auth/login, POST /auth/refresh, POST /auth/invitations/{token}/accept, GET /users/{id} | c4_container | user_account (password_hash argon2id, invited_at, last_login_at), ADR-0009 | TC-AUTH-01…TC-AUTH-07 |
