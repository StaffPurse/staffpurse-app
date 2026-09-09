-- Migration: schedule_anchor_batch
-- Description: Configures daily cron schedule for the anchor-batch Supabase Edge Function using pg_cron & pg_net

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Unschedule any pre-existing job to maintain idempotency
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-anchor-batch') THEN
        PERFORM cron.unschedule('daily-anchor-batch');
    END IF;
END $$;

-- Schedule the daily batch anchoring edge function to run at 00:05 UTC every day
SELECT cron.schedule(
    'daily-anchor-batch',
    '5 0 * * *',
    $$
    SELECT net.http_post(
        url := coalesce(
            current_setting('app.settings.supabase_functions_url', true),
            'https://' || current_setting('app.settings.supabase_project_ref', true) || '.supabase.co/functions/v1'
        ) || '/anchor-batch',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
        ),
        body := jsonb_build_object(
            'trigger', 'cron_daily',
            'scheduled_for', to_char(now() - interval '1 day', 'YYYY-MM-DD')
        )
    );
    $$
);
