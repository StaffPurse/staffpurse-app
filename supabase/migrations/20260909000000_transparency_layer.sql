-- Migration: transparency_layer
-- Created at: 2026-09-09

-- Add merkle_proof to transaction_cache (spend records)
ALTER TABLE transaction_cache ADD COLUMN merkle_proof JSONB;

-- Create dead_letter table for failed Soroban RPC submissions
CREATE TABLE dead_letter (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payload JSONB NOT NULL,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

-- Enable RLS to ensure backend-only access
ALTER TABLE dead_letter ENABLE ROW LEVEL SECURITY;

-- Note: no policies means default-deny for all users.
-- Only service_role can access this table.
