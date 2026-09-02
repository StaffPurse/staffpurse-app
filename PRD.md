# PRD — StaffPurse
*Spend control for Nigeria's informal micro-businesses, built on BMONI*

Status: Draft for hackathon build — BMONI "Hack the Future", Sept 4 2026
Author: Ademola (with Claude — flag anything below you disagree with, this hasn't been pressure-tested by anyone but me)

---

## 1. Problem

A market-stall trader, a single-owner provisions shop, or a small workshop with 2–4 apprentices has the same money-control problem a mid-size company has: staff need to spend the business's money (buy stock, pay a supplier, fuel a delivery bike), but the owner has no way to see who spent what, cap it, or shut it off — short of handing over the one shared debit card or cash from the till and hoping.

**This is not an unclaimed problem.** Bujeti and Prospa already solve it — well — for registered SMEs with finance teams, invoices, and formal payroll. Neither is built for a business that can't produce a CAC certificate, doesn't have a "finance team" (the owner *is* the finance team), and runs on informal trust between the owner and two or three people they already know personally. That segment is the target here — not because it's unclaimed ground, but because it's ground the funded players aren't structured to serve profitably.

**Open risk, stated plainly:** I have not verified that this informal segment is underserved *because* incumbents chose not to serve it, versus underserved because it's genuinely hard to monetize (small transaction volumes, low willingness to pay). If it's the latter, this is a weaker pitch than it sounds. Worth a gut-check with your mentor before you commit a full day to it.

## 2. Who it's for

**Primary user — the Owner.** Runs a shop, stall, or small service business. Has 1–5 people who need to spend the business's money day to day. Currently manages this with cash, a shared card, or verbal trust. Low tolerance for paperwork or setup friction — this has to onboard in minutes on a phone, not require a business registration flow.

**Secondary user — Staff.** Given a card with a hard cap. Doesn't need a full account, dashboard, or login of their own for the MVP — just a card that works until the owner turns it off.

## 3. What the product actually needs to do (MVP)

1. **Owner onboarding** — sign up, verify identity (BVN, via BMONI's KYC), provision a self-custodied wallet, fund it (sandbox NGN in the demo).
2. **Add a staff member** — name + phone number, no separate BMONI account required for them.
3. **Issue a card for that staff member** — virtual card, drawn against the owner's wallet, with an owner-set daily limit and per-transaction limit at creation time.
4. **Adjust a card's limit** — owner changes the cap at any time, takes effect immediately.
5. **Freeze / unfreeze a card** — instant, owner-triggered, no reason required.
6. **See a live spend feed** — per card and combined, so the owner can see who spent what, where, and when without asking.
7. **PIN-gated approval** — every owner action that moves money or changes a card's limit is signed with the owner's on-device PIN (this is BMONI's self-custody model, not optional).

### Explicitly out of scope for the hackathon build
- Physical card issuance/delivery (virtual only)
- Staff-side app or login
- Multi-owner / multi-branch businesses
- Reimbursement or approval-workflow features (that's Bujeti's territory — don't rebuild it)
- Any accounting/bookkeeping export
- Non-NGN currencies

## 4. Why this and not the alternatives already ruled out
- **Corporate card apps generally** — occupied by Bujeti (funded, live) and Prospa (licensed institution). Competing head-on with a one-day build is not a credible claim.
- **Digital Ajo/Esusu** — at least five named, live competitors (My Ajo App, Thrifto, Loopsave, AjoApp, Corral). Also occupied.
- **Cross-border NGN↔MXN/LATAM settlement** — BMONI's rails support this and no direct competitor was found, but I have no evidence Nigeria–LATAM trade volume is real or common enough to matter. Higher differentiation, unverified demand — a bigger bet than this pick.

This pick trades "genuinely novel" for "defensible and buildable": same category as funded competitors, different segment they're structurally not built to serve.

## 5. Success criteria for the demo (Sept 4, 12pm)
- Live, on-stage: fund wallet → issue card to a staff member → set a ₦-limit → simulate a spend that hits the limit and gets blocked → freeze the card → show the transaction feed updated in real time.
- No step relies on undocumented BMONI API behavior. Every call used in the demo should be traceable to a page in BMONI's actual API reference — verify this yourself before the day, don't take my earlier audit as the final word on it.
- The pitch explicitly names Bujeti/Prospa and states *why* this segment is different, rather than pretending they don't exist. Judges are more likely to trust a team that shows it knows the landscape.

## 6. Scope correction, post-architecture-review

Verified against BMONI's actual Cards API reference (previously unverified — see
ARCHITECTURE.md §6 for the full doc excerpt and reasoning).

- **Reversing last turn's call: ship both limit types from day one.** I'd previously told
  you to cut this to one limit type because it was unverified. It's now confirmed — `PUT
  /cards/{cardId}/set-limit` takes `totalDailyLimit` and `maxSingleTransactionAmount` in a
  single call. Both limits are one endpoint, not two separate risky integrations. Build both.
  One real dependency this adds: you must `GET /cards/{cardId}/limits` first to read the
  provider's max caps (`maxTotalDailyLimit`, `maxSingleTransactionLimitCap`) before letting
  the owner set a number, or the provider will reject an out-of-range value.
- **Removing a staff member must freeze their card — with "freeze," not "deactivate."** The
  Cards API is explicit that `deactivate` is a **permanent, irreversible** cancellation,
  separate from freezing (`PUT .../status` with `BLOCKED`, which is reversible). "Remove
  staff member" in the product should map to freezing their card, not deactivating it — an
  owner who re-hires someone, or removes them by mistake, should be able to reverse it. This
  is still part of MVP, not a stretch goal.
- **New requirement discovered: card issuance needs the owner's NIN, not just BVN.** BMONI's
  KYC (BVN) verifies the account. Issuing a card additionally requires the cardholder's
  11-digit NIN — required on the *first* card issued to an owner, not required again after
  that. The original onboarding flow only accounted for BVN. Add NIN collection to owner
  onboarding, before the first card-issuance step, or the first "issue a card" demo action
  will fail with `400 E101 — Card owner is not enrolled for cards yet`.

Also worth having a straight answer ready for, even though it's out of scope to build: a
judge may ask how the staff member knows their card was frozen or their limit changed. Right
now, they don't find out — the owner controls everything and nothing notifies the staff
member. That's a legitimate limitation to state plainly if asked, not something to dodge.

## 7. Open questions to resolve before/while building

Resolved by the real Cards API doc: daily + per-transaction limits (confirmed, one call),
card creation flow shape (confirmed, see below), freeze/unfreeze mechanics (confirmed).

Still open:
- **Card creation's real latency**, specifically the async path: if `signPayloadPending`
  comes back `true`, you must poll `GET .../sign-payload` (a `409` there means "not ready,"
  not an error) before you can sign. Unknown how often this path triggers or how long it
  typically takes in sandbox — if it's common, first-time card issuance live on stage is
  riskier than assumed. Pre-warm a card outside the demo window, don't create one live.
- **How `fundingPolicy` (`SAFE`/`PERSONAL`/`BOTH`) and `fundLifecycle`
  (`ONE_TIME`/`REPEATABLE`) get set.** The create-card request body doesn't expose these as
  parameters, so they're presumably provider-assigned defaults — but if a card defaults to
  `ONE_TIME` funding, it may need an explicit re-fund action rather than continuously
  drawing down the shared wallet balance, which would materially change the product. Confirm
  this before building the funding assumption into the demo.
- Confirm sandbox test BVN, test NIN, and test funding actually work the day before —
  hackathon sandbox environments are the most common source of last-minute demo failure.
