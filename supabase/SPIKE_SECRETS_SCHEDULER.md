# Spike: Supabase Secrets and Scheduler Capabilities

## Secrets Management

Supabase CLI provides robust secrets management for Edge Functions.

**Setting a secret:**
```bash
supabase secrets set STELLAR_SERVICE_SECRET_KEY=S...
```

**Verifying the secret locally:**
When running `supabase functions serve --env-file .env.local`, the edge functions can access secrets using `Deno.env.get("STELLAR_SERVICE_SECRET_KEY")`.

## Scheduler Capabilities (pg_cron and pg_net)

Supabase supports `pg_cron` and `pg_net` to schedule edge function invocations.

**SQL Example for Daily Execution:**

```sql
-- Enable extensions if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule the anchor-batch function to run daily at midnight
SELECT cron.schedule(
  'anchor-batch-daily',
  '0 0 * * *',
  $$
    SELECT net.http_post(
        url:='https://<PROJECT_REF>.supabase.co/functions/v1/anchor-batch',
        headers:='{"Authorization": "Bearer <ANON_KEY>"}'::jsonb
    );
  $$
);
```

Both extensions are supported in standard Supabase environments (version 1.150+).
