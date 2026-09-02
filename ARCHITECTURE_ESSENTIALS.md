# Architecture Essentials — StaffPurse

Quick-reference outline only. Full reasoning and unverified-items list in ARCHITECTURE.md —
read that before making a decision this file doesn't cover.

## Stack (locked)
- **Flutter** mobile app — mandatory, BMONI's SDK/UI kit are Flutter-only
- **Riverpod** — state management (matches BMONI's own package)
- **bmoni_embedded_sdk** — wallet provisioning, PIN, on-device signing (Keystore/Secure Enclave)
- **bkey_uikit** — design system / UI primitives
- **bmoni_embedded_wallets_cards** — wallet/card widgets + Riverpod notifiers
- **Supabase (or Firebase)** — your own backend, Postgres + realtime, for business/staff layer

## The one rule that matters most
BMONI knows users, wallets, cards, KYC, money. **BMONI does not know "business" or "staff"
or "owner permissions."** You build and own that layer. Never treat BMONI as your app's
database — it's a money/identity service you call into.

## Data model (your DB)
```
Business        → owner_bmoni_user_id, owner_wallet_id, name
StaffMember      → business_id, name, phone, status
CardAssignment   → staff_member_id, bmoni_card_id, daily_limit, per_txn_limit, status
TransactionCache → card_assignment_id, bmoni_transaction_id, amount, occurred_at   [cache only, never source of truth]
```

## Core flows (all PIN-signed via SDK where money/limits move) — confirmed against real docs
1. Owner onboard → BVN KYC + **NIN** (required for first card, easy to miss) → wallet
   provisioned → fund wallet
2. Add staff → `POST /cards` (creates card, no limits yet) → sign+submit the returned
   payload (poll `sign-payload` if `signPayloadPending`) → store `bmoni_card_id`
3. Set limits — **separate step, after creation**: `GET /cards/{id}/limits` (read provider
   caps first) → `PUT /cards/{id}/set-limit` with BOTH `totalDailyLimit` AND
   `maxSingleTransactionAmount` in one call
4. Freeze/unfreeze → `GET /cards/{id}` (read current status first — required, see below) →
   `PUT /cards/{id}/status` with `BLOCKED`/`ACTIVE` only. **Never `deactivate`** for
   "remove staff" — that's permanent, freeze is reversible.
5. Transaction feed → poll BMONI per card → merge into cache, **converting units** (see
   below) → never trust a cached status over a live `GET /cards/{id}` read

## Confirmed endpoints (Cards API)
```
POST   /users/{userId}/cards                                  create card
POST   /users/{userId}/smart-wallets/proposals/{id}/sign       sign+submit creation
GET    /users/{userId}/smart-wallets/proposals/{id}/sign-payload   poll if pending
GET    /users/{userId}/smart-wallets/{walletId}/cards          list cards on a wallet
GET    /users/{userId}/cards/{cardId}                          live status (the ONLY route that is)
PUT    /users/{userId}/cards/{cardId}/status                   BLOCKED | ACTIVE only
PUT    /users/{userId}/cards/{cardId}/set-limit                 totalDailyLimit + maxSingleTransactionAmount
GET    /users/{userId}/cards/{cardId}/limits                    read provider caps BEFORE setting
GET    /users/{userId}/cards/{cardId}/transactions               amounts in MAJOR units
PUT    /users/{userId}/cards/{cardId}/deactivate                 PERMANENT — do not wire to "remove staff"
```

## Build order
1. Backend schema (Supabase) — 30–45 min
2. BMONI onboarding: signup → KYC → wallet → fund (do this FIRST, everything depends on it)
3. Card issuance + limits UI
4. Freeze/unfreeze + transaction feed (parallel with 3)
5. Rehearse demo on a **pre-warmed** wallet/card — never provision live on stage

## Resolved (was unverified last pass — now confirmed against real Cards API doc)
- ✅ Card issuance fields, and it's create→sign→submit (proxy auto-approves), not a full
  3-step propose→approve→sign
- ✅ Daily + per-transaction limits: one call, both fields, confirmed
- ✅ Freeze/unfreeze mechanics, and that `deactivate` is a different, irreversible operation

## Still unverified — confirm in hour 1, not hour 10
- [ ] `fundingPolicy`/`fundLifecycle` (`ONE_TIME` vs `REPEATABLE`) — not a create-request
      param, likely server-assigned. If `ONE_TIME`, cards may need explicit re-funding, not
      continuous wallet draw-down. Check what a real sandbox card reports for this.
- [ ] Webhook vs polling for transaction updates — assume polling unless proven otherwise
- [ ] How often the async `signPayloadPending` path triggers and how long it takes —
      pre-warm a demo card, don't create one live
- [ ] Which limit (daily vs per-transaction) is checked first on a decline, and what error
      comes back

## Explicitly out of scope (don't let scope creep in)
Physical cards · staff-side login/app · multi-branch businesses · approval workflows ·
accounting export · non-NGN currencies

## What will break (fix mitigation, not just code)
- Live network chain (app → your backend → BMONI sandbox) on hackathon wifi, on stage —
  **have a recorded fallback demo, this is the #1 risk**
- Owner's device is the *only* copy of the wallet key — no recovery path. Don't test on a
  device you're also using for anything else that day.
- Your DB's card status vs BMONI's real card status can drift (freeze call times out but
  actually succeeded, or vice versa) — UI can lie about card state
- Daily-limit reset timezone (UTC vs WAT) untested — silent off-by-a-day-window bug
- Shared sandbox environment will be slower/flakier on the actual day than solo testing

## Edge cases currently unhandled
- Removing staff does NOT cascade to a freeze call — fix before demo, use `BLOCKED`, never
  `deactivate`
- **NIN not collected in onboarding** — owner's first card-issuance call will fail without it
- Two staff cards can both authorize against one wallet balance with no reservation — race
  condition, unhandled
- Card status is an **open, issuer-defined set** (`pending`/`active`/`inactive`/`frozen`/
  `restricted`/`lost`/`stolen`) — don't build an exhaustive switch, handle what you need and
  fall through to "unavailable"
- Status transitions aren't retriable on failure — `"The current status does not allow it"`
  means read the real status and stop, not retry on a timer (BMONI's own docs cite a card
  retried 4x over 16 hours for nothing)
- Amount fields are in **different units on different endpoints** — card detail/ledger is
  minor units (`"250000"` = ₦2,500), the transactions list is major units (`25.5` = ₦25.50).
  Normalize at the write boundary into your cache or you'll show numbers 100x wrong.
- No fallback if owner's KYC/NIN fails live — need a pre-verified backup account
- Refund/reversal effect on daily limit — undefined
- Staff member has no real link to their card (no notification, no auth) — fine for MVP,
  but have an answer ready if asked

## Cut this — overengineered for one day
- `TransactionCache` sync/invalidation logic — just call BMONI live + pull-to-refresh
- Webhook-vs-polling as a decision to make now — default to manual refresh, don't solve sync
- Two overlapping status enums (staff status + card status) — collapse to one
- Full staff lifecycle UI (edit/reactivate/history) — MVP only needs add + freeze
- Custom theming beyond `bkey_uikit` defaults — not what this demo wins or loses on
- ~~Cutting to one limit type~~ — **reversed**, this was wrong last pass. Both limits are
  one confirmed API call — no engineering cost to building both, don't cut it.
