# Architecture — StaffPurse

Companion to PRD.md. This is the full version — see ARCHITECTURE_ESSENTIALS.md for a
condensed reference if you're feeding this to a coding agent mid-task.

Confidence key used throughout: [Confirmed] = verified against BMONI's live docs during
research. [Assumed] = reasonable default, not verified — check before building on it.

---

## 1. The core architectural fact that shapes everything else

BMONI's API models **individual users, wallets, and cards** — it has no concept of a
"business," "owner," "staff member," or "who is allowed to freeze whose card." [Confirmed —
nothing in BMONI's user/KYC/cards reference exposes a multi-tenant or role concept.]

That means **you need your own thin backend and database** to model the business layer.
BMONI is not a backend-as-a-service for this product — it's a wallet/card/KYC provider you
call into. Don't architect this as "just BMONI + a Flutter UI." You own the business logic;
BMONI owns money movement and identity verification.

## 2. Tech stack

| Layer | Choice | Why |
|---|---|---|
| Mobile client | **Flutter** | Non-negotiable — BMONI's SDK (`bmoni_embedded_sdk`), design system (`bkey_uikit`), and wallet-card widgets (`bmoni_embedded_wallets_cards`) are all Flutter packages. [Confirmed] There is no JS/React path into BMONI's embedded wallet — only the raw REST API, which would mean rebuilding signing/keystore handling yourself. Don't fight this. |
| State management | **Riverpod** | `bmoni_embedded_wallets_cards` ships Riverpod notifiers for wallet/card state. [Confirmed] Matching it avoids bridging two state systems under time pressure. |
| Key storage / signing | Handled entirely by `bmoni_embedded_sdk` | secp256k1 keys generated and held in Android Keystore / iOS Secure Enclave; private key never leaves device. [Confirmed] You do not touch key material directly — you call SDK methods that sign under the hood. |
| Your backend | **Lightweight — Supabase or Firebase** (Postgres + auth + realtime) | You need almost no custom server logic, just a data store for the business/staff/card-mapping layer below, and ideally realtime push for the transaction feed. A full custom Node/Express service is more than a one-day build needs — a BaaS gets you a working backend in an hour. [Assumed — pick whichever you're already fastest in; the choice isn't load-bearing, the data model is.] |
| Money movement, KYC, cards | **BMONI REST API + SDK** | User creation, BVN KYC, wallet provisioning, wallet funding, card issuance, limit-setting, freeze/unfreeze, transaction history. [Confirmed to exist in BMONI's docs — exact request/response shapes not fully verified, see §6.] |

## 3. System diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App (Owner)                     │
│  bkey_uikit (UI)  +  bmoni_embedded_wallets_cards (widgets)  │
│  +  Riverpod (state)  +  your own screens/business logic     │
├──────────────────────────┬────────────────────────────────────┤
│  bmoni_embedded_sdk        │  Your backend client (Supabase)  │
│  (wallet, PIN, signing)    │  (business/staff/mapping CRUD)   │
└──────────────┬─────────────┴───────────────┬──────────────────┘
               │                              │
               ▼                              ▼
    ┌────────────────────┐         ┌───────────────────────┐
    │   BMONI REST API    │         │  Your DB (Postgres)   │
    │  users / KYC /       │         │  businesses, staff,   │
    │  wallets / cards /   │         │  card_assignments     │
    │  transfers           │         └───────────────────────┘
    └────────────────────┘
```

Two systems of record, deliberately: BMONI owns money and identity; your DB owns the
"who's who" of the business. Never try to store BMONI's card/wallet IDs as your source of
truth for balances — always read current balance/limit state live from BMONI, and only
cache it for display.

## 4. Data models (your backend, not BMONI's)

```
Business
├── id (uuid, pk)
├── owner_bmoni_user_id      // BMONI's user id for the owner — [Confirmed] users have IDs
├── owner_wallet_id           // BMONI wallet id the business draws from
├── name
├── created_at

StaffMember
├── id (uuid, pk)
├── business_id (fk → Business)
├── name
├── phone_number
├── status                    // active | removed
├── created_at

CardAssignment
├── id (uuid, pk)
├── staff_member_id (fk → StaffMember)
├── bmoni_card_id              // the card id returned by BMONI on issuance
├── daily_limit_ngn            // last value YOU set — cache for display, not truth
├── per_transaction_limit_ngn
├── status                     // active | frozen | revoked
├── issued_at

TransactionCache (optional — nice-to-have for the demo, not required)
├── id (uuid, pk)
├── card_assignment_id (fk)
├── bmoni_transaction_id
├── amount_ngn
├── merchant / description
├── occurred_at
├── synced_at
```

`TransactionCache` exists only so the owner's feed loads fast without hammering BMONI's API
on every screen open. Treat it as a read cache, refreshed on pull-to-refresh or a
webhook/poll — never as the record judges should trust if it disagrees with BMONI's own
transaction endpoint.

**Confirmed gotcha — normalize units on write into this cache.** BMONI's own docs flag that
two different endpoints report amounts in two different formats: the card detail/ledger
route (`GET /cards/{cardId}`) reports `amount` as a **minor-unit string** (`"250000"` =
₦2,500.00), while the transactions route (`GET /cards/{cardId}/transactions`) reports
`amount` as a **major-unit number** (`25.5` = ₦25.50 — the docs' own example uses USD but the
same split applies to whichever endpoint you're reading). If you populate `TransactionCache`
from both routes without converting to one common unit first, you will silently mix values
100x apart. Pick one internal unit (minor, i.e. kobo, is safer) and convert at the write
boundary, not the display boundary.

## 5. Core flows

**5.1 Owner onboarding**
1. Owner opens app → creates account → BMONI KYC (BVN) via SDK. [Confirmed: BVN-based
   single-stage KYC exists for NGN.]
2. SDK provisions wallet on-device (key generated in Keystore/Secure Enclave).
3. Your app creates a `Business` row, linking `owner_bmoni_user_id` + `owner_wallet_id`.
4. Fund wallet (sandbox NGN).

**5.2 Add staff + issue card** [Confirmed against BMONI's Cards API reference]
1. Owner adds staff member (name, phone) → row in `StaffMember`.
2. App calls `POST /v1/users/{userId}/cards` with `cardName`, `cardColor`, `currency: "NGN"`,
   `type: "virtual"`, `smartWalletId`, and `nin` (owner's 11-digit NIN — required only on
   this owner's *first* card ever; omitted after that). Note: initial limits are **not**
   set at creation time — this call only creates the card.
3. Response returns a `signPayload` (already auto-approved — BMONI's proxy approves the
   proposal for you, unlike a plain transfer). Sign it via `bmoni_embedded_sdk` with the
   owner's PIN, then submit: `POST .../smart-wallets/proposals/{proposalId}/sign`.
   - If `signPayloadPending: true` instead, poll `GET .../proposals/{proposalId}/sign-payload`
     until it resolves (a `409` there means "not ready," not a failure) — then sign/submit.
4. On success, store `bmoni_card_id` in `CardAssignment`.
5. **Set limits as a separate, second step** — see 5.3. A freshly created card has no
   spending limits set until you explicitly call `set-limit`.
6. While the proposal is unsigned, the card shows in the wallet's card list as a
   **reserved** entry (`status: RESERVED`, `isReserved: true`, keyed by `proposalId` since it
   has no card id yet) — build the UI to handle this transitional state, don't assume a card
   exists the instant the create call returns.

**5.3 Set / adjust limits** [Confirmed — corrects last turn's "ship one limit type" call]
1. Owner picks a card → app first calls `GET /cards/{cardId}/limits` to read
   `maxTotalDailyLimit` and `maxSingleTransactionLimitCap` — the provider's ceilings.
2. Owner sets a value within those ceilings → `PUT /cards/{cardId}/set-limit` with
   `{ totalDailyLimit, maxSingleTransactionAmount }` — **one call sets both.** This was
   flagged unverified last turn; it isn't a risk anymore, build both from day one.
3. On success, update the cached limits in `CardAssignment`.

**5.4 Freeze/unfreeze** [Confirmed]
1. Owner taps freeze → `PUT /cards/{cardId}/status` with `{ "status": "BLOCKED" }`. Unfreeze
   is the same endpoint with `"ACTIVE"`. These are the **only two values the client can set**
   — anything else is rejected with a `400` before it reaches BMONI's provider.
2. **Do not use `deactivate` for this.** `PUT .../deactivate` permanently cancels a card and
   cannot be reversed — it's a different, one-way operation. "Remove staff member" in your
   product must map to `BLOCKED`, never to `deactivate`, unless you genuinely mean "this card
   can never be used again."
3. There is no published state-transition matrix — the issuer validates each transition
   server-side and rejects disallowed ones with the literal string `"The current status does
   not allow it"`. **This is not a transient error and retrying will not fix it** (BMONI's
   own docs cite a card retried four times over sixteen hours against an unchanged state).
   Always `GET /cards/{cardId}` to read the live status before attempting a transition, and
   surface the current status to the owner if a freeze/unfreeze is rejected, rather than
   silently retrying.
4. This should be the *fastest*-feeling action in the app — it's the "oh no" button — but the
   status-check-first requirement above means it's a minimum two-call sequence
   (read-then-write), not one. Design the UI so the check feels invisible.

**5.5 Transaction feed**
1. Poll (or webhook, if BMONI supports one — unverified) BMONI's transaction endpoint per
   card, or in aggregate for the wallet.
2. Merge into `TransactionCache`, display combined + per-card views.

## 6. Verification status

**Resolved** (confirmed against BMONI's actual Cards API reference, pasted in full during
review — everything in §5.2–5.4 above reflects this, not assumption):
- Card issuance field names and shape: `POST /users/{userId}/cards` with `cardName`,
  `cardColor`, `currency`, `type`, `smartWalletId`, `nin` (first card only).
- Card issuance is **not** a plain single call, but it's also not a full three-actor
  propose→approve→sign — BMONI's proxy auto-approves the proposal, so it's create (returns
  a payload already approved) → sign → submit, with an optional poll step if the payload
  isn't ready yet.
- Daily and per-transaction limits **are** two separate fields, settable together in a
  single `set-limit` call.
- Freeze/unfreeze is a two-value (`BLOCKED`/`ACTIVE`) status endpoint, distinct from the
  permanent, irreversible `deactivate` endpoint.

**Still open — confirm before building on it:**
- **Webhook vs polling for transactions.** Not addressed in the Cards reference (which
  covers issuance/limits/status, not push notifications). Still design for polling as the
  safe default.
- **How `fundingPolicy` (`SAFE`/`PERSONAL`/`BOTH`) and `fundLifecycle`
  (`ONE_TIME`/`REPEATABLE`) get assigned to a card.** These fields exist on the card object
  but aren't parameters in the create request — likely provider-assigned defaults. If a card
  defaults to `ONE_TIME` funding rather than continuously drawing the wallet balance, that
  changes the funding model this design assumes. Verify directly (check what a freshly
  created sandbox card actually reports for these fields) before demo day.
- **Async issuance latency.** How often `signPayloadPending: true` triggers, and how long
  the async payload-preparation typically takes, is unknown. Budget for it by pre-warming a
  card before the demo rather than creating one live.
- **The transfers endpoint itself** (referenced by the Cards doc as "the same flow, in
  full") hasn't been independently reviewed — the cards doc describes it by analogy, not
  directly. If your build needs raw transfers (e.g. initial wallet funding) beyond what
  cards need, read `/api-reference/transfers` directly rather than inferring it from the
  cards page's summary.

## 7. Hard questions — what breaks, what's missing, what's overbuilt

### 7.1 What will break

- **The demo depends on a live network call chain (your app → your backend → BMONI
  sandbox), on hackathon wifi, on stage.** This is the single biggest risk to the whole
  project, not a code bug. If any hop is slow or flaky at 12pm on the day, the demo dies in
  front of judges. Mitigation isn't "write better code" — it's a recorded fallback video of
  a working run, cut to live if the room's network embarrasses you.
- **Owner's device is a single point of failure for the entire business.** The private key
  lives only in that device's Keystore/Secure Enclave — self-custody has no recovery path by
  design. [Confirmed as the architecture; recovery mechanism, if any, not verified.] If the
  demo phone crashes, gets factory-reset, or the app gets reinstalled mid-demo, the wallet
  and every card on it may be unreachable with no fallback. Don't test on a device you're
  also using for anything else that day.
- **Two systems of record drifting.** `CardAssignment.status` in your DB and the actual
  card status in BMONI can disagree — a freeze call that times out on your end but actually
  succeeded on BMONI's, or vice versa. If you poll instead of trusting a webhook-confirmed
  write, the UI can show "frozen" while the card still works, or "active" while it's dead.
  This is the kind of bug that looks fine in rehearsal and breaks live because timing
  differs.
- **Daily-limit reset boundary.** If "daily" resets at UTC midnight instead of WAT, a limit
  that looks fully available at 1am WAT is actually already mostly consumed from the
  previous UTC day, or vice versa. Untested timezone logic is a classic silent-failure bug.
- **Sandbox KYC/funding flakiness.** Test BVNs and sandbox funding are third-party
  infrastructure you don't control, shared across every team at the hackathon hitting the
  same environment simultaneously. Assume it will be slower or less reliable on the day
  itself than when you tested it alone at midnight.

### 7.2 Edge cases the current design misses

- **Removing a staff member doesn't cascade.** `StaffMember.status = removed` is modeled,
  but nothing in the flows above says the associated `CardAssignment` gets auto-frozen. As
  written, you can fire someone in the app and their card keeps working. Fix: removal must
  trigger `PUT .../status → BLOCKED` — **not** `deactivate`, which is permanent and
  irreversible per BMONI's docs. An owner who removes someone by mistake, or re-hires them,
  needs to be able to unfreeze.
- **NIN collection is missing from onboarding.** Card issuance requires the owner's 11-digit
  NIN on their first card — not modeled anywhere in the current onboarding flow, which only
  accounted for BVN-based KYC. Without this, the first "issue a card" action in the demo
  fails outright.
- **Insufficient wallet balance mid-day.** Two staff cards drawing against one shared
  wallet balance can both attempt to authorize near-simultaneously. Nothing in this design
  reserves funds per pending transaction — a race condition where both succeed against a
  balance that could only cover one is possible and unhandled.
- **Which limit wins, and what error comes back.** Confirmed that `totalDailyLimit` and
  `maxSingleTransactionAmount` are both real, provider-enforced fields — but which one is
  checked first when a transaction is under one cap and over the other, and what the decline
  reason looks like, is still not documented in what's been reviewed. Confirm this before
  writing UI copy for a decline.
- **Card status is an open, issuer-defined set — don't build a UI that assumes it's
  exhaustive.** Beyond the two states you can set (`BLOCKED`/`ACTIVE`), a card can report
  `pending`, `active`, `inactive`, `frozen`, `restricted`, `lost`, or `stolen` — read
  case-insensitively, and BMONI's own docs warn this set is open-ended (an issuer can add a
  new one without a BMONI-side change). Handle the ones your demo needs and fall through to
  a neutral "unavailable" state for anything else — don't assert an exhaustive switch
  statement.
- **`GET /cards/status?workflowId=…` is a naming trap.** It polls the *creation workflow*,
  not the card's live status — despite the name. The only route that reports a live card's
  actual status is `GET /cards/{cardId}`. Easy to call the wrong one and get confusing
  results; worth a comment in the code, not just a memory to rely on.
- **Card expiry.** Virtual cards from any issuer typically have an expiry date; not
  addressed in what's been reviewed of BMONI's docs. Low risk for a one-day demo, but if a
  card is issued the night before and expires unexpectedly, that's a bad live-demo surprise.
- **Refund/reversal doesn't restore a limit.** If a staff transaction is refunded, does the
  daily limit "give back" that amount, or stay consumed until the reset? Not addressed — and
  it's the kind of question a sharp judge might actually ask.
- **KYC rejection with no fallback.** The whole demo assumes the owner's BVN sandbox
  verification succeeds. There's no described path for what the demo does if it doesn't —
  you need a pre-verified backup account, not just a hope that verification works live.
- **No real link to the staff member as a person.** `StaffMember.phone_number` is stored but
  nothing sends them anything or authenticates them — the card is functionally anonymous
  plastic controlled entirely by the owner. That's fine for MVP scope, but if a judge asks
  "how does the staff member know their limit changed," the honest answer right now is "they
  don't," and that's worth having a prepared answer for rather than being caught by it.

### 7.3 What's overengineered for a one-day build

- **`TransactionCache` as a sync layer.** Building cache-write, cache-invalidation, and
  merge logic against a live API is real engineering effort for a problem a "pull to
  refresh, call BMONI live, show a spinner" approach solves with far less surface area for
  bugs. Cut it unless the live call is proven too slow to use directly — don't build it
  preemptively.
- **Polling vs webhook as a design decision at all, right now.** This doesn't need solving
  before you build. Default to a manual refresh button. Decide on background sync only if
  you have spare time on day two — there is no day two.
- **Two separate status enums doing overlapping work.** `StaffMember.status
  (active|removed)` and `CardAssignment.status (active|frozen|revoked)` model more state
  than the demo needs. For the hackathon, a single `CardAssignment.status` is probably
  enough — removing a staff member *is* revoking their card, they don't need to be separate
  concepts yet.
- **Retracted from last review: cutting to one limit type was the wrong call.** Both limits
  are confirmed to be a single API call, not two integrations — there's no risk-reduction
  benefit to cutting one, so build both. What *is* worth trimming: don't build a generic
  "handle every possible issuer card status" UI (see §7.2) — that open-ended status set is
  real complexity BMONI's own docs tell you not to fully enumerate. Handle
  `active`/`frozen`/`pending` for the demo and fall through to a generic state for the rest.
- **Full staff lifecycle management (edit, reactivate, history).** The demo needs "add a
  staff member, issue a card." It does not need edit flows, reactivation, or a staff
  directory with search — that's product-polish work for after the hackathon, not before it.
- **Custom theming beyond `bkey_uikit` defaults.** Spending demo-day time making the app
  look distinctively "yours" instead of using BMONI's design system as-is is time not spent
  on the parts that are actually unverified and risky (§6). Visual originality is not what
  this pitch is winning or losing on.

## 8. Build order (roughly a one-day team split)

1. Backend schema + Supabase project (30–45 min) — one person
2. BMONI SDK integration: user signup, KYC, wallet provisioning, wallet funding (first big
   chunk, do this first since everything else depends on it) — one person
3. Card issuance + limit-setting UI, wired to real API calls once step 2 is proven working
4. Freeze/unfreeze + transaction feed (can be built in parallel with 3 once the auth/signing
   pattern from step 2 is established, since it's the same PIN-signing pattern repeated)
5. Demo script rehearsal with a **pre-warmed** business/wallet/card set — don't do first-time
   provisioning live on stage; that's where sandbox latency or flakiness will hurt you most
