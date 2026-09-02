# PROMPT.md — Building StaffPurse with Antigravity CLI

This assumes you're building the project described in PRD.md / ARCHITECTURE.md /
ARCHITECTURE_ESSENTIALS.md, using Google's Antigravity CLI (`agy`) as your primary coding
agent. Confirmed facts about Antigravity CLI below are sourced from Google's own docs and
release coverage as of this writing — the exact CLI flags for non-interactive/scripted use
weren't independently verified, run `agy --help` yourself before relying on any flag not
shown here.

---

## Part 1 — Environment setup

### 1.1 Install Flutter (if not already installed)
Follow Flutter's own install docs for your OS — not repeated here, this project just needs
a working `flutter` on PATH before Antigravity CLI is useful for it.

### 1.2 Install Antigravity CLI

```bash
# macOS / Linux
curl -fsSL https://antigravity.google/cli/install.sh | bash

# Windows (PowerShell)
irm https://antigravity.google/cli/install.ps1 | iex
```

Antigravity CLI is Google's terminal-first coding agent (successor to Gemini CLI), ships as
a single binary (`agy`), and supports multiple model providers under one CLI — not locked
to Gemini.

### 1.3 First run / authentication
```bash
agy
```
First launch walks you through one-time sign-in (Google OAuth by default; SSH and
enterprise-credential paths also exist if you're not on a personal machine). The resulting
token is stored in your OS's native keyring — you shouldn't need to re-auth per session.

**Only ever launch `agy` from inside your project directory**, not your home folder or
another repo. It reads/writes/executes with your permission scoped to wherever you start it.

### 1.4 Useful commands to know before you start
```
/agents       — manage sub-agents / agent configs
/mcp          — manage MCP server connections
/skills       — manage installed skills
/permissions  — review/adjust what the agent can do without asking
/resume       — pick up a previous session
/rewind       — undo agent actions
/tasks        — background task management
```
Set `/permissions` deliberately before your first real prompt — decide now whether you want
to approve every file write and shell command individually (safer, slower) or grant broader
autonomy (faster, riskier) for this project. Given the amount of unverified BMONI API
surface documented in ARCHITECTURE.md §6, lean toward requiring approval on anything that
touches real API calls, sandbox credentials, or `git push`.

---

## Part 2 — GitHub repo setup

```bash
mkdir staffpurse && cd staffpurse
git init
flutter create . --org com.yourorg.staffpurse --platforms=android,ios

# Place these five files at the repo root before your first agent prompt:
#   PRD.md
#   ARCHITECTURE.md
#   ARCHITECTURE_ESSENTIALS.md
#   AGENTS.md
#   CLAUDE.md

git add .
git commit -m "chore: project scaffold + planning docs"
```

Create the GitHub repo and push (via `gh` CLI if you have it, otherwise the web UI):
```bash
gh repo create staffpurse --private --source=. --remote=origin
git push -u origin main
```

**Why the docs go in before any code:** Antigravity CLI reads `AGENTS.md` from the project
root automatically as context for every session. If it's not there yet when you start
prompting, the agent has no grounding in the decisions already made — you'll get generic
Flutter scaffolding instead of a build that respects the architecture you already worked
out.

### 2.1 Supabase project (manual step — not agent-automatable)
Create the Supabase project yourself at supabase.com before prompting the agent to write any
backend code — the agent can write schema/migrations against it, but project creation and
getting your connection credentials is a manual dashboard step. Add the resulting URL/anon
key to a `.env` file, and make sure `.env` is in `.gitignore` before your first commit that
touches it.

---

## Part 3 — Prompt sequence

Run these roughly in order. Each assumes the agent has already read `AGENTS.md` (automatic)
— you don't need to re-paste the architecture into every prompt, just reference it.

### Prompt 0 — verification pass (run this before any code)
```
Before writing any code, read PRD.md, ARCHITECTURE.md, and ARCHITECTURE_ESSENTIALS.md in
full. ARCHITECTURE.md §6 lists items that are still unverified against BMONI's live docs:
fundingPolicy/fundLifecycle assignment, webhook vs polling for transactions, and the real
transfers endpoint. If you have web access, check BMONI's docs at bkey.mintlify.app for
these specifically and report back what you find before we proceed — don't guess or
silently assume an answer for any of them. If you don't have web access, tell me explicitly
which of these three you need me to fetch and paste in before you start building against
that part of the API.
```

### Prompt 1 — backend schema
```
Set up the Supabase schema described in ARCHITECTURE.md §4 (Business, StaffMember,
CardAssignment, TransactionCache tables). Use the Supabase CLI / migrations, not manual
dashboard changes, so the schema is version-controlled in this repo. Follow the field names
and types exactly as documented — don't invent additional columns without asking me first.
```

### Prompt 2 — BMONI onboarding flow (do this before anything else user-facing)
```
Implement the owner onboarding flow from ARCHITECTURE.md §5.1: BVN-based KYC via
bmoni_embedded_sdk, wallet provisioning, and sandbox wallet funding. Per PRD.md §6, also
collect the owner's NIN during onboarding — BMONI's Cards API requires it on the first card
issued to any owner, and I'd rather collect it upfront than have the first card-issuance
demo action fail on stage. Use bkey_uikit components for the UI, don't build custom form
widgets where a BMoniTextFormField or similar already exists.
```

### Prompt 3 — card issuance + limits
```
Implement staff creation and card issuance per ARCHITECTURE.md §5.2: POST /users/{userId}/
cards with cardName, cardColor, currency=NGN, type=virtual, smartWalletId, and nin (first
card only). Handle the signPayload response — sign via bmoni_embedded_sdk, submit via the
proposals/{proposalId}/sign endpoint, and handle the signPayloadPending case by polling
sign-payload (409 = not ready, keep polling, don't treat as an error). Show the card as
"reserved" in the UI while the proposal is unsigned, per §5.2 point 6.

Then implement limit-setting per §5.3: GET the card's /limits first to read the provider's
caps, then PUT /set-limit with both totalDailyLimit and maxSingleTransactionAmount in one
call. Reject and explain, rather than silently clamp, if the owner tries to set a value
above the provider's cap.
```

### Prompt 4 — freeze/unfreeze + transaction feed
```
Implement freeze/unfreeze per ARCHITECTURE.md §5.4: PUT /cards/{cardId}/status with BLOCKED
or ACTIVE only. Before every status change, GET /cards/{cardId} to read the live status
first — if the transition is rejected with "The current status does not allow it", do not
retry automatically; surface the actual current status to the owner instead. Never call
/deactivate for the "remove staff member" action — that's permanent per the docs, freeze
is what we want.

Then implement the transaction feed: poll GET /cards/{cardId}/transactions, and when writing
into TransactionCache, normalize amounts to minor units (kobo) at the write boundary — the
card detail/ledger endpoint returns minor-unit strings while the transactions endpoint
returns major-unit numbers, per ARCHITECTURE.md §4. Don't let these mix.
```

### Prompt 5 — demo rehearsal data
```
Write a setup script (not part of the app itself) that pre-provisions one demo business,
two staff members, and two issued+limited cards against the sandbox, so we have a
pre-warmed state to demo from rather than provisioning live on stage. Keep the credentials
for this out of version control.
```

### Ongoing — code review discipline
For every prompt above, actually read the diff before accepting it. This project has more
unverified API surface than a typical hackathon build (see ARCHITECTURE.md §6) — an agent
that's uncertain about a field name will sometimes guess plausibly instead of flagging the
uncertainty, and a plausible-looking wrong guess is exactly the kind of bug that survives
to demo day. If a diff includes an API call or field name that isn't in ARCHITECTURE.md or
the pasted doc excerpts, stop and verify it against the live docs before merging, don't take
the agent's confidence as confirmation.
