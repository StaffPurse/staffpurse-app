# Architecture Essentials

**Repository**: `staffpurse-app`
**Purpose**: Primary mobile application for StaffPurse spend management, plus the backend cron jobs for anchoring transparency proofs to Soroban.

### 1. Stack
- **Frontend**: Flutter (Mobile), Riverpod, BMONI SDKs.
- **Backend**: Supabase (Postgres, Edge Functions/Cron).

### 2. Core Mechanisms
1. **Card Management**: Handled via `bmoni_embedded_sdk` and `bmoni_embedded_wallets_cards` strictly on the mobile client.
2. **Anchoring Job**: A backend cron task that gathers daily spend records, computes a Merkle tree, saves the individual proofs back to Postgres, and submits the Merkle root to the `staffpurse-contracts` on Stellar.

### 3. Critical Constraints
- **Hardware Enclave**: The mobile app strictly relies on hardware keystores for EIP-191 signing (BMONI requirement).
- **Service-Owned Signer**: The Soroban anchoring job uses a service-owned Stellar key. Business owners *do not* manage Stellar keys.
- **Resilience**: The anchoring job must have retry/backoff logic. A failed Soroban submission must not silently drop a batch or block the mobile app.
