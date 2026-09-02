---
name: AGENTS.md
description: Canonical agent instructions for the StaffPurse project. Read by Antigravity CLI automatically; imported into CLAUDE.md for Claude Code (see that file's note on why).
---

# Agent instructions — StaffPurse

Read PRD.md, ARCHITECTURE.md, and ARCHITECTURE_ESSENTIALS.md before making any change that
touches product scope or the BMONI integration. This file is the quick-reference layer on
top of those — if something here conflicts with ARCHITECTURE.md, ARCHITECTURE.md wins;
update this file to match rather than trusting whichever you read most recently.

## What this project is

A Flutter app that lets a small-business owner issue capped virtual spend cards to staff,
against a single self-custodied BMONI smart wallet. Full context: PRD.md. Segment: informal
Nigerian micro-businesses too small for Bujeti/Prospa's structured-SME model — see PRD.md §4
for why that matters to scope decisions.

## Tech stack (do not deviate without asking)
- Flutter — mandatory, BMONI's SDK/UI kit are Flutter-only, there is no other path in
- Riverpod — state management, matches `bmoni_embedded_wallets_cards`'s own notifiers
- `bmoni_embedded_sdk` / `bkey_uikit` / `bmoni_embedded_wallets_cards` — BMONI's packages,
  use them rather than rebuilding equivalents
- Supabase (Postgres) — your own backend for the business/staff/card-mapping layer BMONI
  doesn't model (see below)

## The one architectural fact that governs everything
BMONI knows users, wallets, cards, KYC, money movement. **BMONI does not know "business,"
"staff member," or "who's allowed to freeze whose card."** That layer is this project's own
backend and database — never architect a feature as if BMONI will store or enforce it for
you. Full data model: ARCHITECTURE.md §4.

## Confirmed BMONI Cards API — use these exact shapes, don't guess field names
```
POST   /users/{userId}/cards                                   create (see required fields below)
POST   /users/{userId}/smart-wallets/proposals/{id}/sign        sign + submit creation
GET    /users/{userId}/smart-wallets/proposals/{id}/sign-payload   poll if signPayloadPending
GET    /users/{userId}/smart-wallets/{walletId}/cards           list cards on a wallet
GET    /users/{userId}/cards/{cardId}                           live status — the ONLY route that is
PUT    /users/{userId}/cards/{cardId}/status                    body: {"status": "BLOCKED"|"ACTIVE"} only
PUT    /users/{userId}/cards/{cardId}/set-limit                 totalDailyLimit + maxSingleTransactionAmount, one call
GET    /users/{userId}/cards/{cardId}/limits                    read provider caps BEFORE setting a limit
GET    /users/{userId}/cards/{cardId}/transactions               amounts in MAJOR units
PUT    /users/{userId}/cards/{cardId}/deactivate                 PERMANENT — never wire to "remove staff"
```
Create-card required fields: `cardName`, `cardColor` (hex), `currency` (`NGN`/`USD`), `type`
(`virtual` for this project), `smartWalletId`, `nin` (owner's 11-digit NIN, first card only).

## Rules that exist because a real bug or gotcha was found in BMONI's docs — don't relearn these the hard way
1. **Freeze, never deactivate, for "remove staff."** `deactivate` is permanent and
   irreversible. `PUT .../status → BLOCKED` is what "remove staff member" means in this
   product.
2. **Read status before writing status.** `"The current status does not allow it"` is not a
   transient error — BMONI's own docs cite a card retried four times over sixteen hours
   against an unchanged state. Always `GET /cards/{cardId}` first; never retry a rejected
   status transition on a timer.
3. **Card status is an open, issuer-defined set.** Handle
   `pending`/`active`/`inactive`/`frozen`/`restricted`/`lost`/`stolen` case-insensitively and
   fall through to a neutral "unavailable" state for anything unrecognized — don't write an
   exhaustive switch and assume it will stay exhaustive.
4. **Two amount formats, don't mix them.** Card detail/ledger amounts are minor-unit strings
   (`"250000"` = ₦2,500). The transactions list returns major-unit numbers (`25.5` =
   ₦25.50). Normalize to one unit (minor/kobo) at the point you write into
   `TransactionCache`, not at display time.
5. **`GET /cards/status?workflowId=…` is not card status.** It polls the creation workflow.
   The only route for live card status is `GET /cards/{cardId}`. Don't confuse the two.
6. **NIN is required on first card, BVN KYC is separate.** Onboarding must collect both —
   BVN for account KYC, NIN before the first card-issuance call, or that call fails.

## Still genuinely unverified — flag, don't silently assume
See ARCHITECTURE.md §6 for the live list. As of the last review it includes: how
`fundingPolicy`/`fundLifecycle` gets assigned to a card, webhook vs polling for transaction
updates, and the real `/api-reference/transfers` endpoint shape (only described by analogy
in the Cards doc so far). If a task touches one of these, say so explicitly rather than
building on an assumption — ask for the relevant doc page to be pasted in if you don't have
live web access.

## Scope discipline
Out of scope for this build, do not add unprompted: physical card issuance/delivery,
staff-side login or app, multi-branch businesses, approval/reimbursement workflows,
accounting export, non-NGN currencies. Full list: PRD.md §3.

## Working conventions
- Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`) for anything landing on `main`
- Don't invent database columns, API parameters, or BMONI endpoints not documented in
  ARCHITECTURE.md or the doc excerpts pasted into this repo's history — ask rather than
  guess plausibly
- When a BMONI call fails, surface the actual error from the API in logs/UI during
  development rather than swallowing it into a generic "something went wrong"
- Keep `.env` / sandbox credentials out of version control
