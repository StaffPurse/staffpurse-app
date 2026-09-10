# 🗺️ ROADMAP.md — `staffpurse-app`

> **Scope:** Getting `staffpurse-app` approved into the Stellar Wave Program, deploying the Supabase transparency layer and daily Soroban anchoring Edge Functions, maintaining Flutter mobile app hygiene, and running community-driven Wave cycles.
> **Note:** Wave Program does not fund StaffPurse directly; community contributors earn points by completing backlog issues.

---

## Phase 0 — Feasibility & Ecosystem Prerequisites

Pre-implementation validation of Supabase infrastructure, Stellar keypair security, and mobile client compatibility.

### 📋 Current Work
- [x] **Wave Program Acceptance Confirmed:** Stellar Wave Program is active.
- [x] **Architecture Topology Defined:** Flutter App → Supabase DB → Supabase Edge Function (`anchor-batch`) → Soroban RPC.

### 🔍 Identified Gaps & Action Items (Now Tracked in GitHub Issues)
- [x] **Issue #13 — Supabase Secrets & Scheduler Capabilities Spike:** [Verify Supabase Edge Function secrets management and scheduler capabilities](https://github.com/StaffPurse/staffpurse-app/issues/13)
- [x] **Points Allocation Budget:** Confirm exact Wave 1 points ceiling for `staffpurse-app` on the Drips dashboard (target: ~25,000 pts).

---

## Phase 1 — Repository Hygiene & Transparency Backend

Requirements to clean up hackathon debris, structure the Supabase batching pipeline, and prepare the repository for Wave audit.

### 📋 Current Work (Tracked in GitHub Issues)
- [x] **Issue #1 — Security & Service Topology:** [Add SECURITY.md and Explicit Topology Diagram](https://github.com/StaffPurse/staffpurse-app/issues/1) ✅ *(Completed by @mallison031)*
- [x] **Issue #2 — Edge Function Scaffolding:** [Scaffold Supabase Edge Function for daily batching](https://github.com/StaffPurse/staffpurse-app/issues/2)
- [x] **Issue #3 — Merkle Tree Construction:** [Implement Merkle tree construction utility](https://github.com/StaffPurse/staffpurse-app/issues/3) ✅ *(Completed by @mallison031)*
- [x] **Issue #4 — Stellar SDK Submission Logic:** [Implement Stellar SDK Soroban submission logic](https://github.com/StaffPurse/staffpurse-app/issues/4)
- [x] **Issue #5 — Resilience & Dead-Letter Queue:** [Implement retry and dead-letter queue for RPC failures](https://github.com/StaffPurse/staffpurse-app/issues/5) ✅ *(Completed by @mallison031)*
- [x] **Issue #6 — Database Migrations:** [Write Supabase SQL schema migrations for the transparency layer](https://github.com/StaffPurse/staffpurse-app/issues/6)
- [x] **Issue #7 — Edge Function CI Pipeline:** [Set up GitHub Actions CI for Edge Function validation](https://github.com/StaffPurse/staffpurse-app/issues/7) ✅ *(Completed by @mallison031)*
- [x] **Issue #8 — Hackathon Scripts Cleanup:** [Clean up leftover hackathon patch and fix scripts](https://github.com/StaffPurse/staffpurse-app/issues/8)
- [x] **Issue #9 — Test & Artifact Cleanup:** [Clean up leftover test scripts, diffs, and stray images](https://github.com/StaffPurse/staffpurse-app/issues/9) ✅ *(Completed by @mallison031)*
- [x] **Issue #14 — Automated Daily Batch Scheduler:** [Configure automated daily batch scheduler via pg_cron and pg_net](https://github.com/StaffPurse/staffpurse-app/issues/14) ✅ *(Completed by @mallison031)*
- [x] **Issue #15 — Edge Function Setup & Keypair Guide:** [Author Supabase Edge Function environment setup and service keypair guide](https://github.com/StaffPurse/staffpurse-app/issues/15)
- [x] **Issue #16 — Mobile Blockchain Verification Link:** [Add 'Verify on Stellar' link to Transaction Details in Flutter](https://github.com/StaffPurse/staffpurse-app/issues/16) ✅ *(Completed by @mallison031)*
- [x] **Issue #17 — Flutter CI Pipeline:** [Set up GitHub Actions CI workflow for Flutter analysis and testing](https://github.com/StaffPurse/staffpurse-app/issues/17)

### 🔍 Identified Gaps & Action Items
- [x] ~~**GAP-A1: Daily Batch Job Scheduler / Cron Trigger**~~ → Created as **Issue #14**
- [x] ~~**GAP-A2: Service Keypair Funding & Secret Injection Guide**~~ → Created as **Issue #15**
- [x] ~~**GAP-A3: Mobile App Transparency Link (Flutter Integration)**~~ → Created as **Issue #16**
- [x] ~~**GAP-A4: Flutter Mobile CI Workflow**~~ → Created as **Issue #17**

---

## Phase 3 — Wave Issue Backlog & Point Sizing

Preparing a production-grade issue backlog for Wave contributors.

### 📋 Current Work
- [x] Standard Drips Wave issue template created in `.github/ISSUE_TEMPLATE/drips-wave-issue.md`.
- [x] Initial Phase 1 issues (#1–#9) published with comprehensive guidelines.

### 🔍 Identified Gaps & Action Items
- [ ] **GAP-A5: GitHub Labels Configuration:**
  - *Problem:* Repository only has default labels (`bug`, `enhancement`).
  - *Action:* Create labels:
    - `complexity: trivial (100 pts)`
    - `complexity: medium (150 pts)`
    - `complexity: high (200 pts)`
    - `wave-1`
- [ ] **GAP-A6: Issue Sizing & Point Assignment:**
  - *Problem:* Current open issues do not display point values in their metadata.
  - *Action:* Tag existing issues:
    - `#1` Security & Topology → Trivial (100 pts)
    - `#2` Edge Function Scaffolding → Medium (150 pts)
    - `#3` Merkle Tree Construction → High (200 pts)
    - `#4` Stellar SDK Submission → High (200 pts)
    - `#5` Retry & Dead Letter Queue → Medium (150 pts)
    - `#6` SQL Migrations → Medium (150 pts)
    - `#7` Edge CI Workflow → Trivial (100 pts)
    - `#8` Cleanup Patch Scripts → Trivial (100 pts)
    - `#9` Cleanup Test Files → Trivial (100 pts)
- [ ] **GAP-A7: Wave 2 Feature Backlog Seeding:**
  - *Problem:* No queued backlog for subsequent Wave cycles.
  - *Action:* Draft Wave 2 candidate issues:
    - Dead-letter queue alert webhook (e.g. Discord / Telegram notification on failed batch).
    - Batch compression & multi-tenant organization sharding.
    - Automated proof backfill script for historical spend records.

---

## Phase 4 — Wave 1 Operational Execution

Managing contributors during the 1-week Wave execution cycle.

### 📋 Current Work
- [x] Community support channels (Telegram & Discord) added to issue guidelines.
- [x] Code Quality Standards outlined in `CONTRIBUTING.md`.

### 🔍 Identified Gaps & Action Items
- [ ] **GAP-A8: Pull Request Template (`.github/PULL_REQUEST_TEMPLATE.md`):**
  - *Problem:* No PR template defining acceptance testing for both Supabase edge functions and Flutter code.
  - *Action:* Create PR template with checkboxes for Deno tests, Supabase migrations, and Flutter tests.
- [ ] **GAP-A9: Contributor Inactivity SLA:**
  - *Problem:* Assigned contributors may stall during the 1-week sprint.
  - *Action:* Enforce 48-hour re-assignment rule for unstarted tasks.
- [ ] **GAP-A10: Issue Template Placeholder Cleanup:**
  - *Problem:* `.github/ISSUE_TEMPLATE/drips-wave-issue.md` still contains placeholder strings (`[link]`, `$org/$repo`).
  - *Action:* Replace with concrete StaffPurse links.

---

## Phase 5 — Iteration & Wave Closeout

Post-cycle review, point distribution, and backlog maintenance.

### 📋 Current Work
- [ ] Retrospective cadence defined.

### 🔍 Identified Gaps & Action Items
- [ ] **GAP-A11: Drips Attestation Workflow:** Document verification procedure to approve point claims on Drips portal within 14 days of merge.
- [ ] **GAP-A12: Production Migration & Dead Letter Monitoring:** Review Supabase logs, inspect dead letter queue table, and tune Soroban transaction fees.
- [ ] **GAP-A13: Budget Reconciliation:** Rebalance points spent against repo allocation for Wave 2 planning.

---

## Open Decisions & Technical Risks
1. **PII and Data Leakage:** Ensure no sensitive employee names, banking details, or card numbers are hashed directly into Merkle leaves without salting/anonymization.
2. **Keypair Rotation:** Strategy for rotating the backend Stellar service secret key without interrupting scheduled daily anchoring.
3. **Empty Batch Handling:** If no transactions occur on a given day, should the edge function anchor an empty root hash (`0x0...`) or skip anchoring for that date?
