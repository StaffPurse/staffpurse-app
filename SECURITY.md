# Security Policy

## Threat Model & Security Scope

StaffPurse bridges corporate spend management with public cryptographic proof on the Stellar blockchain (Soroban). For architectural details, consult [ARCHITECTURE.md](ARCHITECTURE.md).

## Supported Versions

Only the latest `main` branch and active releases are supported with security patches.

| Version | Supported |
| ------- | --------- |
| `main` (`v0.1.x`) | :white_check_mark: |
| `< 0.1.0` | :x: |

## Reporting a Vulnerability

If you discover a security vulnerability in StaffPurse, **do not report it publicly** via GitHub issues, discussions, or social media.

### Preferred Reporting Channel
Submit a private report via **[GitHub Private Vulnerability Reporting](https://github.com/StaffPurse/staffpurse-app/security/advisories/new)** directly to the core maintainers.

### Secondary Contact
If private reporting is unavailable, reach out privately to the maintainers:
- **Telegram:** Maintainers direct contact in [StaffPurse Group](https://t.me/+Gflo5jZStw1jMjE0)
- **Discord:** Direct message core maintainers in [StaffPurse Server](https://discord.gg/5aprtMSyR)

## Scope

### In-Scope
- Mobile client key security and keystore interactions (`bmoni_embedded_sdk`).
- Supabase Edge Functions (`anchor-batch`) handling daily Merkle tree generation and Stellar submission.
- Backend database migrations, RLS policies, and dead-letter queue structures.
- Service-owned signer access control and secret isolation.

### Out-of-Scope
- Physical device compromises or rooted/jailbroken runtime vulnerabilities.
- BMONI upstream API and third-party banking services.
- Soroban smart contract logic (covered in [`staffpurse-contracts`](https://github.com/StaffPurse/staffpurse-contracts)).
- Web verification frontend (covered in [`staffpurse-web`](https://github.com/StaffPurse/staffpurse-web)).
- Stellar consensus network and public RPC node outages.

## Response SLA & Disclosure Policy

- **Initial Triage:** Maintainers will acknowledge and assess report severity within **48 hours**.
- **Status Updates:** Progress updates provided every **5 business days** during active remediation.
- **Coordinated Disclosure:** We follow a standard **90-day coordinated disclosure timeline** before public advisory release.

> [!NOTE]
> The transparency layer and backend Edge Functions in this repository are currently in **testnet/pre-audit stage**. Exercise appropriate diligence in production deployments.
