-- Migration: init_schema
-- Created at: 2026-09-02

-- Business table
CREATE TABLE business (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_bmoni_user_id TEXT NOT NULL,
    owner_wallet_id TEXT NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- StaffMember table
CREATE TABLE staff_member (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES business(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('active', 'removed')) DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- CardAssignment table
CREATE TABLE card_assignment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_member_id UUID NOT NULL REFERENCES staff_member(id) ON DELETE CASCADE,
    bmoni_card_id TEXT NOT NULL,
    daily_limit_ngn BIGINT,
    per_transaction_limit_ngn BIGINT,
    status TEXT NOT NULL CHECK (status IN ('active', 'frozen', 'revoked')) DEFAULT 'active',
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- TransactionCache table
CREATE TABLE transaction_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_assignment_id UUID NOT NULL REFERENCES card_assignment(id) ON DELETE CASCADE,
    bmoni_transaction_id TEXT NOT NULL UNIQUE,
    amount_ngn BIGINT NOT NULL,
    description TEXT,
    occurred_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
