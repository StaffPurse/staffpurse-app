-- Migration: add_business_owner_id
-- Created at: 2026-09-03
--
-- The app queries and inserts `business.owner_id` (the Supabase auth user id)
-- in main.dart, auth_screen.dart, dashboard_screen.dart and
-- onboarding_service.dart, but the original init_schema migration never
-- created the column. This adds it idempotently so both fresh setups and
-- projects that already applied init_schema converge on the same shape.

ALTER TABLE business
    ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);