-- Migration: add_anchored_batches
-- Created at: 2026-09-14

-- AnchoredBatches table
CREATE TABLE anchored_batches (
    batch_date TEXT PRIMARY KEY, -- e.g., '20260914'
    root_hash TEXT NOT NULL,
    stellar_transaction_hash TEXT NOT NULL,
    total_records INT NOT NULL,
    anchored_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Extend transaction_cache to store the batch it belongs to and its Merkle proof
ALTER TABLE transaction_cache
ADD COLUMN batch_date TEXT REFERENCES anchored_batches(batch_date),
ADD COLUMN merkle_proof JSONB;

-- Create an index for quick lookups by batch date
CREATE INDEX idx_transaction_cache_batch ON transaction_cache(batch_date);
