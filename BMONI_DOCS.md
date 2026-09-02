https://bkey.mintlify.app/<page>

## Must read before writing any code

| Page | Why | Confidence |
|---|---|---|
| `/lifecycle` | The six-stage flow (User→Wallet→KYC→Rail→Fund→Move money) everything else assumes. ARCHITECTURE.md's whole flow section is built on this. | Page confirmed to exist, content unverified — worth pasting in |
| `/sdk/wallet-provisioning` | How you actually create the owner's on-device wallet — this is Prompt 2 in PROMPT.md and I've never seen its real content | Page confirmed to exist, content unverified |
| `/sdk/signing` | Exact signing call signature for the sign-and-submit step in card issuance. I flagged this as never independently verified back when we wrote ARCHITECTURE.md §6 — still true | Page confirmed to exist, content unverified |
| `/api-reference/kyc-nga-requirements` | BVN KYC flow specifics — I read this once early on but it aged out of context before you pasted anything from it. Needed for Prompt 2 (onboarding) | Read once, not re-verified |
| `/api-reference/cards` | Already have this — fully verified, it's what ARCHITECTURE.md §5.2-5.4 is built from | ✅ Fully verified |

## Read when you get to that specific feature

| Page | When you need it |
|---|---|
| `/api-reference/transfers` | Referenced by the Cards doc as "the same flow, in full" for the proposal→approve→sign pattern — needed to fund the wallet initially (Prompt 2), and I've only ever seen it described by analogy, never directly |
| `/api-reference/ngn-rails` | Referenced in the Cards doc's "Related" section as how you fund the wallet a card spends from — this is the actual mechanics of Prompt 2's "fund wallet" step |
| `/api-reference/errors` | Read once, aged out — worth a fresh read once you're actually wiring error handling, so you know the full catalog rather than the handful of codes I mentioned in passing |
| `/sdk/introduction` | General SDK setup/install — probably needed once, early, alongside wallet-provisioning |
| `/uikit/installation` | Package setup for `bkey_uikit` — needed once, when you scaffold the Flutter project |
| `/wallets/widgets` | The prebuilt `EmbeddedWalletCard` / `EmbeddedWalletTransactionsSection` widgets — could save you from hand-building the card/transaction UI, worth checking before you build those screens from scratch |

## Lower priority / check only if something breaks

- `/uikit/introduction` and individual component pages (like the `buttons` example you gave) — you already have a working alternate source for this: `bkey_uikit`'s pub.dev page, which I read in full earlier and it documents every component (buttons, form fields, sheets, wallet cards, etc.) with real code examples. Unless the Mintlify version has something pub.dev doesn't, I'd treat pub.dev as sufficient here and not spend a doc-fetch on it.
- `/api-reference/integration-flow` — described in the Cards doc as "every endpoint in call order." Possibly a useful cross-check once you've built the flow, to catch anything you missed — not something you need before starting.
- `/quickstart` — generic getting-started, probably superseded by ARCHITECTURE.md's more specific flow once you're past initial setup.

## What I'd explicitly skip for this project
Anything about USD accounts, SEPA payouts, MXN ramps, or physical card activation/delivery — all real sections in BMONI's docs per the overview page, none relevant to StaffPurse's NGN-only, virtual-card-only MVP scope.

**Practical suggestion given how this has gone so far:** the pattern that worked well was you pasting a page's content directly when my fetch access hit a wall (like the Cards page). If you're going through this list yourself anyway, pasting the top four "must read" pages in as you go would let me re-verify ARCHITECTURE.md §6 further and close out more of the "still unverified" list before you're deep into building.