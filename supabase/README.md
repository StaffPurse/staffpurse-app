# Supabase Edge Functions & Setup

This guide provides instructions for configuring local development, managing secrets, and testing the edge functions.

## Local Setup

1. Make sure you have the [Supabase CLI](https://supabase.com/docs/guides/cli) installed.
2. Start the local Supabase stack:
   ```bash
   supabase start
   ```
3. Serve the edge functions locally:
   ```bash
   supabase functions serve
   ```

## Creating & Funding a Stellar Service Keypair

To submit Merkle roots to Soroban, you need a Stellar service keypair funded on the Testnet.

1. Generate a new keypair and fund it using Friendbot:
   ```bash
   curl "https://friendbot.stellar.org/?addr=<NEW_PUBLIC_KEY>"
   ```

## Environment Configuration

Create a `.env.local` file in the `supabase/` directory with the following variables:

```env
STELLAR_SERVICE_SECRET_KEY=S...
SOROBAN_RPC_URL=https://soroban-testnet.stellar.org
CONTRACT_ID=C...
```

## Running Unit Tests

To run edge function unit tests using Deno:

```bash
deno test supabase/functions/
```
