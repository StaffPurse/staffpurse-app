> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# KYC — Nigeria (NGN + USD)

> KYC requirements for opening NGN and USD accounts for Nigerian users. Provisioned in two separate stages

<div className="bmoni-spine">
  <span>Lifecycle</span>
  <a data-stage="1" href="/lifecycle#1-create-the-user">User</a>
  <a data-stage="2" href="/lifecycle#2-provision-the-smart-wallet">Wallet</a>
  <a data-stage="3" href="/lifecycle#3-verify-identity-kyc">KYC</a>
  <a data-stage="4" href="/lifecycle#4-activate-the-rail">Rail</a>
  <a data-stage="5" href="/lifecycle#5-fund-the-wallet">Fund</a>
  <a data-stage="6" href="/lifecycle#6-move-money">Move money</a>
</div>

The two accounts are provisioned in separate stages.

***

## Stage 1: NGN local account

**Triggered by:** `POST /onboarding/start-nigeria`

**Required at call time:**

| Field              |                                              |
| ------------------ | -------------------------------------------- |
| `bvn`              | required — 11-digit Bank Verification Number |
| `ngnWalletAddress` | required                                     |
| `ngnWalletIndex`   | required                                     |

The BVN is verified and used to auto-populate KYC profile fields. Proxy users run a single wallet address across currencies, so the NGN wallet is mirrored onto the USD fields server-side — no separate USD wallet address is passed here.

<Info>
  Helper lookups (verify without saving): `GET /kyc/bvn-lookup/:bvn` and `GET /kyc/nin-lookup/:nin` return the holder's details so you can pre-fill or confirm before submitting.
</Info>

<Note>
  **Test BVN:** use `22222222222` in the sandbox. It returns a fixed set of holder details and always verifies successfully — real BVNs are not accepted outside production.
</Note>

**Personal Info**

| Field         |                          |
| ------------- | ------------------------ |
| `firstName`   | required                 |
| `lastName`    | optional                 |
| `phoneNumber` | required — min 10 digits |
| `dateOfBirth` | required                 |
| `gender`      | optional                 |

**Address** (must be a Nigerian address)

| Field         |                                                                                       |
| ------------- | ------------------------------------------------------------------------------------- |
| `streetLine1` | required                                                                              |
| `city`        | required                                                                              |
| `state`       | required — must be a valid Nigerian state name (stored upstream as `subdivisionName`) |
| `postalCode`  | required — 6 digits                                                                   |
| `countryCode` | required — `"NGA"`                                                                    |

**Identification Numbers**

| Field |                                     |
| ----- | ----------------------------------- |
| `bvn` | required — 11 digits, `type: "bvn"` |

***

## Stage 2: USD international account — Enhanced Due Diligence

**Triggered by:** `POST /kyc/activate`

Nigeria is a high-risk jurisdiction, so the USD account requires Enhanced Due Diligence (EDD). All [USD core requirements](/api-reference/kyc-usd-requirements) apply, plus:

**Employment**

| Field                         |                                                  |
| ----------------------------- | ------------------------------------------------ |
| `employment.employmentStatus` | required                                         |
| `employment.occupationCode`   | required, non-null — from `GET /kyc/occupations` |
| `employment.employerName`     | optional                                         |

**Financial / Compliance**

| Field                    |                                                            |
| ------------------------ | ---------------------------------------------------------- |
| `sourceOfFunds`          | required — cannot be `"salary"` if unemployed or a student |
| `estimatedMonthlyVolume` | required, in USD                                           |
| `accountPurpose`         | defaults to `"personal"`                                   |
| `actingAsIntermediary`   | defaults to `false`                                        |

**Identification Document (uploaded)**

* At least one document of type: `passport`, `drivers_license`, `national_id`, or `government_id`
* Must include a `front` or `additional` image file
* `documentNumber` — required
* `issuingCountryCode` — required

***

## Key notes

* BVN verification happens automatically during the Nigeria onboarding workflow. The KYC profile is populated from the verified BVN data.
* The Nigeria workflow only provisions the NGN (local) account. The USD account is provisioned later via `POST /kyc/activate`, then `POST /onboarding/start-usa` (gated on `GET /kyc/usd-readiness`), once KYC data is complete.
