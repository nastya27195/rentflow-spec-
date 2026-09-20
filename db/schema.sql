-- RentFlow — схема PostgreSQL 15, версия 2.0. Источник истины по структуре данных.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE organization (
  id UUID PRIMARY KEY, name TEXT NOT NULL, inn TEXT,
  timezone TEXT NOT NULL DEFAULT 'Europe/Moscow',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON COLUMN organization.timezone IS 'IANA-зона. Все DATE-поля биллинга и запуск job трактуются в этой зоне (ADR-0007)';

CREATE TABLE tenant (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  name TEXT NOT NULL, inn TEXT, email TEXT, phone TEXT,
  type TEXT NOT NULL DEFAULT 'LEGAL_ENTITY' CHECK (type IN ('LEGAL_ENTITY','SOLE_PROPRIETOR','INDIVIDUAL')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_tenant_org ON tenant (organization_id);
COMMENT ON COLUMN tenant.type IS 'Тип арендатора: юрлицо / ИП / физлицо. ИНН обязателен для всех, кроме INDIVIDUAL (ck_tenant_inn)';
ALTER TABLE tenant ADD CONSTRAINT ck_tenant_inn CHECK (type = 'INDIVIDUAL' OR inn IS NOT NULL);

CREATE TABLE user_account (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT,                       -- argon2id; NULL до принятия приглашения (ADR-0009)
  invited_at TIMESTAMPTZ, last_login_at TIMESTAMPTZ,
  role TEXT NOT NULL CHECK (role IN ('ADMIN','MANAGER','TENANT')),
  tenant_id UUID REFERENCES tenant(id),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_user_tenant_role CHECK ((role = 'TENANT') = (tenant_id IS NOT NULL)),
  CONSTRAINT ck_user_active_has_password CHECK (NOT is_active OR password_hash IS NOT NULL OR invited_at IS NOT NULL)
);
CREATE INDEX ix_user_account_tenant ON user_account (tenant_id) WHERE tenant_id IS NOT NULL;

CREATE TABLE property (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  name TEXT, address TEXT NOT NULL, area_sqm NUMERIC(10,2) NOT NULL CHECK (area_sqm > 0),
  type TEXT NOT NULL CHECK (type IN ('OFFICE','RETAIL','WAREHOUSE','RESIDENTIAL')),
  archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_property_org ON property (organization_id);

CREATE TABLE contract (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  property_id UUID NOT NULL REFERENCES property(id), tenant_id UUID NOT NULL REFERENCES tenant(id),
  status TEXT NOT NULL CHECK (status IN ('DRAFT','ACTIVE','SUSPENDED','EXPIRED','TERMINATED')),
  rent_amount NUMERIC(14,2) NOT NULL CHECK (rent_amount > 0),
  currency CHAR(3) NOT NULL DEFAULT 'RUB',
  billing_period TEXT NOT NULL CHECK (billing_period IN ('MONTHLY','QUARTERLY')),
  billing_day SMALLINT NOT NULL DEFAULT 1 CHECK (billing_day BETWEEN 1 AND 28),
  grace_days SMALLINT NOT NULL DEFAULT 5 CHECK (grace_days >= 0),
  penalty_rate_pct NUMERIC(6,4) NOT NULL DEFAULT 0.1000 CHECK (penalty_rate_pct >= 0),
  start_date DATE NOT NULL, end_date DATE NOT NULL, next_billing_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_contract_dates CHECK (end_date > start_date),
  CONSTRAINT ex_contract_property_period EXCLUDE USING gist
    (property_id WITH =, daterange(start_date, end_date, '[]') WITH &&)
    WHERE (status IN ('ACTIVE','SUSPENDED'))
);
COMMENT ON COLUMN contract.penalty_rate_pct IS 'Процент от остатка долга ЗА ДЕНЬ. 0.1000 = 0,1 %/день. Пеня дня = остаток x rate / 100';
CREATE INDEX ix_contract_billing  ON contract (next_billing_date) WHERE status = 'ACTIVE';
CREATE INDEX ix_contract_property ON contract (property_id);
CREATE INDEX ix_contract_tenant   ON contract (tenant_id);
CREATE INDEX ix_contract_expiring ON contract (end_date) WHERE status = 'ACTIVE';

CREATE TABLE invoice (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  contract_id UUID NOT NULL REFERENCES contract(id), tenant_id UUID NOT NULL REFERENCES tenant(id),
  period_start DATE NOT NULL, period_end DATE NOT NULL, issue_date DATE NOT NULL, due_date DATE NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'RUB',
  amount         NUMERIC(14,2) NOT NULL DEFAULT 0,  -- агрегат: сумма invoice_line (триггер)
  penalty_amount NUMERIC(14,2) NOT NULL DEFAULT 0,  -- агрегат: сумма penalty (триггер)
  paid_amount    NUMERIC(14,2) NOT NULL DEFAULT 0,  -- агрегат: сумма payment CONFIRMED (триггер)
  overpaid_amount NUMERIC(14,2) GENERATED ALWAYS AS (GREATEST(paid_amount - amount - penalty_amount, 0)) STORED,
  status TEXT NOT NULL CHECK (status IN ('DRAFT','ISSUED','PARTIALLY_PAID','PAID','CANCELLED')),
  overdue_since DATE,                               -- ось срока, отдельно от оси оплаты
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_invoice_period UNIQUE (contract_id, period_start),
  CONSTRAINT ck_invoice_period CHECK (period_end > period_start),
  CONSTRAINT ck_invoice_due    CHECK (due_date >= issue_date),
  CONSTRAINT ck_invoice_amounts CHECK (amount >= 0 AND penalty_amount >= 0 AND paid_amount >= 0),
  CONSTRAINT ck_invoice_paid_status CHECK (status <> 'PAID' OR paid_amount >= amount + penalty_amount)
);
COMMENT ON COLUMN invoice.overdue_since IS 'Счёт просрочен <=> overdue_since IS NOT NULL AND status IN (ISSUED, PARTIALLY_PAID)';
COMMENT ON COLUMN invoice.overpaid_amount IS 'Переплата. Платёж не отклоняется: счёт → PAID, излишек зачитывается строкой OVERPAYMENT_CREDIT в следующий счёт договора (FR-49, ADR-0010)';
CREATE INDEX ix_invoice_status_due ON invoice (status, due_date);
CREATE INDEX ix_invoice_tenant     ON invoice (tenant_id);
CREATE INDEX ix_invoice_contract   ON invoice (contract_id);
CREATE INDEX ix_invoice_overdue    ON invoice (organization_id, overdue_since)
  WHERE overdue_since IS NOT NULL AND status IN ('ISSUED','PARTIALLY_PAID');

CREATE TABLE invoice_line (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  invoice_id UUID NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
  source_invoice_id UUID REFERENCES invoice(id),   -- для OVERPAYMENT_CREDIT: счёт, с которого зачтена переплата
  kind TEXT NOT NULL CHECK (kind IN ('RENT','ADJUSTMENT','OVERPAYMENT_CREDIT')),   -- PENALTY убран: источник истины - penalty
  description TEXT, amount NUMERIC(14,2) NOT NULL
);
CREATE INDEX ix_invoice_line_invoice ON invoice_line (invoice_id);
COMMENT ON COLUMN invoice_line.kind IS 'RENT — аренда; ADJUSTMENT — ручная корректировка; OVERPAYMENT_CREDIT — зачёт переплаты предыдущего счёта (amount < 0, создаёт billing-job)';
ALTER TABLE invoice_line ADD CONSTRAINT ck_invoice_line_sign CHECK ((kind = 'OVERPAYMENT_CREDIT') = (amount < 0));
CREATE UNIQUE INDEX uq_invoice_line_overpay_source ON invoice_line (source_invoice_id) WHERE kind = 'OVERPAYMENT_CREDIT';

CREATE TABLE penalty (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  invoice_id UUID NOT NULL REFERENCES invoice(id),
  accrual_date DATE NOT NULL, days_overdue SMALLINT NOT NULL CHECK (days_overdue >= 1),
  base_amount NUMERIC(14,2) NOT NULL, rate_pct NUMERIC(6,4) NOT NULL, amount NUMERIC(14,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_penalty_day UNIQUE (invoice_id, accrual_date)
);

CREATE TABLE idempotency_key (
  user_id UUID NOT NULL REFERENCES user_account(id), key UUID NOT NULL,
  request_hash TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'IN_PROGRESS' CHECK (state IN ('IN_PROGRESS','COMPLETED')),
  response_status SMALLINT, response_body JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), expires_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (user_id, key)
);
CREATE INDEX ix_idempotency_expires ON idempotency_key (expires_at);

CREATE TABLE payment (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  invoice_id UUID NOT NULL REFERENCES invoice(id),
  payer_user_id UUID REFERENCES user_account(id),
  idempotency_user_id UUID, idempotency_key UUID,
  amount NUMERIC(14,2) NOT NULL CHECK (amount > 0), currency CHAR(3) NOT NULL DEFAULT 'RUB',
  status TEXT NOT NULL CHECK (status IN ('PENDING','CONFIRMED','FAILED','CANCELLED','EXPIRED','REFUNDED')),
  provider TEXT NOT NULL, provider_payment_id TEXT,
  failure_reason TEXT, refund_provider_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ, refunded_at TIMESTAMPTZ,
  CONSTRAINT uq_payment_provider UNIQUE (provider, provider_payment_id),
  CONSTRAINT fk_payment_idempotency FOREIGN KEY (idempotency_user_id, idempotency_key)
    REFERENCES idempotency_key(user_id, key) ON DELETE SET NULL,
  CONSTRAINT ck_payment_confirmed CHECK (status NOT IN ('CONFIRMED','REFUNDED') OR confirmed_at IS NOT NULL),
  CONSTRAINT ck_payment_failed CHECK (status <> 'FAILED' OR failure_reason IS NOT NULL)
);
CREATE INDEX ix_payment_invoice ON payment (invoice_id);

CREATE TABLE task (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  type TEXT NOT NULL CHECK (type IN ('OVERDUE_FOLLOWUP','CONTRACT_EXPIRING','MANUAL')),
  invoice_id UUID REFERENCES invoice(id), contract_id UUID REFERENCES contract(id),
  assignee_id UUID REFERENCES user_account(id), title TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'NORMAL' CHECK (priority IN ('LOW','NORMAL','HIGH')),
  status TEXT NOT NULL DEFAULT 'NEW' CHECK (status IN ('NEW','IN_PROGRESS','DONE','CANCELLED')),
  due_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_task_reference CHECK (
       (type = 'OVERDUE_FOLLOWUP'  AND invoice_id  IS NOT NULL)
    OR (type = 'CONTRACT_EXPIRING' AND contract_id IS NOT NULL)
    OR (type = 'MANUAL'))
);
CREATE UNIQUE INDEX uq_task_overdue_open ON task (invoice_id)
  WHERE type = 'OVERDUE_FOLLOWUP' AND status IN ('NEW','IN_PROGRESS');
CREATE INDEX ix_task_assignee_status ON task (assignee_id, status);
CREATE INDEX ix_task_contract ON task (contract_id) WHERE contract_id IS NOT NULL;

CREATE TABLE notification (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  tenant_id UUID REFERENCES tenant(id), user_id UUID REFERENCES user_account(id),
  type TEXT NOT NULL, channel TEXT NOT NULL CHECK (channel IN ('EMAIL','SMS','PUSH')),
  recipient_address TEXT NOT NULL, template TEXT NOT NULL, text TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'QUEUED' CHECK (status IN ('QUEUED','SENT','FAILED')),
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), sent_at TIMESTAMPTZ,
  CONSTRAINT ck_notification_recipient CHECK (tenant_id IS NOT NULL OR user_id IS NOT NULL),
  CONSTRAINT ck_notification_push CHECK (channel <> 'PUSH' OR user_id IS NOT NULL)
);
CREATE INDEX ix_notification_user_unread ON notification (user_id) WHERE read = false;
CREATE INDEX ix_notification_tenant ON notification (tenant_id) WHERE tenant_id IS NOT NULL;

CREATE TABLE outbox_event (
  id UUID PRIMARY KEY, organization_id UUID NOT NULL REFERENCES organization(id),
  aggregate_type TEXT NOT NULL, aggregate_id UUID NOT NULL,
  event_type TEXT NOT NULL, schema_version SMALLINT NOT NULL DEFAULT 1,
  topic TEXT NOT NULL, partition_key TEXT NOT NULL, payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), published_at TIMESTAMPTZ, attempts SMALLINT NOT NULL DEFAULT 0
);
CREATE INDEX ix_outbox_unpublished ON outbox_event (created_at) WHERE published_at IS NULL;

CREATE TABLE processed_event (
  consumer TEXT NOT NULL, event_id UUID NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (consumer, event_id)
);

CREATE TABLE audit_log (
  id BIGSERIAL PRIMARY KEY, organization_id UUID, entity_type TEXT NOT NULL, entity_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
  changed_by UUID, changed_at TIMESTAMPTZ NOT NULL DEFAULT now(), old_data JSONB, new_data JSONB
);
CREATE INDEX ix_audit_entity ON audit_log (entity_type, entity_id);

CREATE OR REPLACE FUNCTION trg_audit() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_row JSONB := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
BEGIN
  INSERT INTO audit_log(organization_id, entity_type, entity_id, action, changed_by, old_data, new_data)
  VALUES ((v_row->>'organization_id')::uuid, TG_TABLE_NAME, (v_row->>'id')::uuid, TG_OP,
          nullif(current_setting('app.current_user', true), '')::uuid,
          CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
          CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);
  RETURN NULL;
END $$;
CREATE TRIGGER audit_contract AFTER INSERT OR UPDATE OR DELETE ON contract FOR EACH ROW EXECUTE FUNCTION trg_audit();
CREATE TRIGGER audit_invoice  AFTER INSERT OR UPDATE OR DELETE ON invoice  FOR EACH ROW EXECUTE FUNCTION trg_audit();
CREATE TRIGGER audit_payment  AFTER INSERT OR UPDATE OR DELETE ON payment  FOR EACH ROW EXECUTE FUNCTION trg_audit();

-- Единственный механизм пересчёта агрегатов счёта (ADR-0004)
CREATE OR REPLACE FUNCTION fn_invoice_recalc(p_invoice_id UUID) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_amount NUMERIC(14,2); v_penalty NUMERIC(14,2); v_paid NUMERIC(14,2);
BEGIN
  SELECT COALESCE(SUM(amount),0) INTO v_amount  FROM invoice_line WHERE invoice_id = p_invoice_id;
  SELECT COALESCE(SUM(amount),0) INTO v_penalty FROM penalty      WHERE invoice_id = p_invoice_id;
  SELECT COALESCE(SUM(amount),0) INTO v_paid    FROM payment      WHERE invoice_id = p_invoice_id AND status = 'CONFIRMED';
  UPDATE invoice SET amount = v_amount, penalty_amount = v_penalty, paid_amount = v_paid,
    status = CASE WHEN status IN ('ISSUED','PARTIALLY_PAID','PAID') THEN
               CASE WHEN v_paid >= v_amount + v_penalty AND v_amount + v_penalty > 0 THEN 'PAID'
                    WHEN v_paid > 0 THEN 'PARTIALLY_PAID' ELSE 'ISSUED' END
             ELSE status END,
    updated_at = now()
  WHERE id = p_invoice_id;
END $$;
CREATE OR REPLACE FUNCTION trg_invoice_recalc() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM fn_invoice_recalc(COALESCE(NEW.invoice_id, OLD.invoice_id));
  RETURN NULL;
END $$;
CREATE TRIGGER recalc_on_invoice_line AFTER INSERT OR UPDATE OR DELETE ON invoice_line FOR EACH ROW EXECUTE FUNCTION trg_invoice_recalc();
CREATE TRIGGER recalc_on_penalty      AFTER INSERT OR UPDATE OR DELETE ON penalty      FOR EACH ROW EXECUTE FUNCTION trg_invoice_recalc();
CREATE TRIGGER recalc_on_payment      AFTER INSERT OR UPDATE OR DELETE ON payment      FOR EACH ROW EXECUTE FUNCTION trg_invoice_recalc();

-- Изоляция по organization_id: RLS на всех бизнес-таблицах (ADR-0006).
-- Сервис выполняет SET LOCAL app.current_org = '<uuid из токена>' в начале транзакции.
DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY['tenant','user_account','property','contract','invoice','invoice_line',
                           'penalty','payment','task','notification','outbox_event','audit_log'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format($p$CREATE POLICY p_org_isolation ON %I USING
      (organization_id = nullif(current_setting('app.current_org', true), '')::uuid)$p$, t);
  END LOOP; END $$;
