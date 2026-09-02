> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Cards — issue and manage spend cards

> Issue virtual or physical NGN/USD cards against a smart wallet, then activate, freeze, limit, and read them through the partner API.

<div className="bmoni-spine">
  <span>Lifecycle</span>
  <a data-stage="1" href="/lifecycle#1-create-the-user">User</a>
  <a data-stage="2" href="/lifecycle#2-provision-the-smart-wallet">Wallet</a>
  <a data-stage="3" href="/lifecycle#3-verify-identity-kyc">KYC</a>
  <a data-stage="4" href="/lifecycle#4-activate-the-rail">Rail</a>
  <a data-stage="5" href="/lifecycle#5-fund-the-wallet">Fund</a>
  <a data-stage="6" href="/lifecycle#6-move-money">Move money</a>
</div>

A card spends a smart wallet's balance. Every partner card is issued **against a smart wallet** — there is no user-level card — so the wallet must exist and be funded before a card is useful.

Card creation goes through the same **proposal → approve → sign** flow as a transfer, with one difference: the proxy approves the proposal for you and returns the payload to sign straight from the create call.

***

## 1. Create the card

```http theme={null}
POST /v1/users/{userId}/cards
{
  "cardName": "Payroll Card",
  "cardColor": "#4285F4",
  "currency": "NGN",
  "type": "virtual",
  "smartWalletId": "7f4d6b88-80a0-4d3f-9538-9a4dfabc1234",
  "nin": "12345678901"
}
```

| Field                                                     |                                                                                                 |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `cardName`                                                | required — 1–50 characters                                                                      |
| `cardColor`                                               | required — hex colour, `#RGB` or `#RRGGBB`                                                      |
| `currency`                                                | required — `NGN` or `USD`                                                                       |
| `type`                                                    | required — `virtual` or `physical`                                                              |
| `smartWalletId`                                           | required — the wallet that funds the card                                                       |
| `nin`                                                     | the cardholder's 11-digit Nigerian NIN. Required the **first** time this owner is issued a card |
| `state`                                                   | Nigerian state for physical delivery. Any common spelling; bmoni normalises it                  |
| `deliveryAddress`, `deliveryState`, `deliveryPhoneNumber` | physical delivery details. Phone accepts `+234`, `234`, or `0` prefixes                         |
| `pan`                                                     | 13–19 digits — a physical card already in the cardholder's hand. Skips delivery                 |
| `otpChannel`                                              | `sms` or `email` — where the activation OTP goes                                                |
| `ninIssueDate`, `ninExpiryDate`                           | accepted but unused by the card provider. Safe to omit                                          |

<Warning>
  Omitting `nin` for an owner who has never been issued a card returns `400 E101 — Card owner is not enrolled for cards yet`. Once enrolled, later cards for that owner do not need it.
</Warning>

The response tells you what to sign:

```json theme={null}
{
  "flow": "group",
  "feeAmount": "1000",
  "feeCurrency": "NGN",
  "proposalId": "b7c9e9a2-6a54-4f24-9a83-2f6f7c1d9e10",
  "proposalStatus": "PENDING_APPROVALS",
  "signPayload": { }
}
```

| Field                       |                                                                         |
| --------------------------- | ----------------------------------------------------------------------- |
| `flow`                      | `group` for every smart-wallet card. `personal` is not used by partners |
| `feeAmount` / `feeCurrency` | the on-chain creation fee charged to the wallet                         |
| `proposalId`                | the issuance proposal — already approved on your behalf                 |
| `signPayload`               | the EVM payload to sign                                                 |
| `signPayloadPending`        | `true` when the payload was not ready in time (see below)               |
| `signPayloadHint`           | present with `signPayloadPending` — the exact next call                 |
| `signPayloadError`          | present only when fetching the payload failed unexpectedly              |

## 2. Sign and submit

Sign `signPayload` with the wallet owner key via `bmoni_embedded_sdk`, then submit it:

```http theme={null}
POST /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign
{
  "signature": "0x…"
}
```

If `signPayloadPending` came back `true`, the payload is still being prepared asynchronously. Poll for it first, then sign and submit as above:

```http theme={null}
GET /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign-payload
```

<Note>
  A `409` on the sign-payload route means "not ready yet", not an error — keep polling. Track the issuance itself with `GET /v1/users/{userId}/smart-wallets/proposals/{proposalId}`.
</Note>

If the response carries `migrationRequired: true` instead of a proposal, the wallet is a legacy (pre-Safe) wallet that cannot hold cards. Managed wallets migrate automatically and the create is retried in the same request; when the sweep is still confirming, follow `migrationHint` — sign the attached payload if present, otherwise retry card creation shortly.

***

## Read cards

Cards are listed and read on the **smart-wallet** path, not the user path.

| Action                            | Endpoint                                                                        |
| --------------------------------- | ------------------------------------------------------------------------------- |
| List the wallet's cards           | `GET /v1/users/{userId}/smart-wallets/{smartWalletId}/cards`                    |
| One card, with balance and ledger | `GET /v1/users/{userId}/smart-wallets/{smartWalletId}/cards/{cardId}`           |
| Provider card identity            | `GET /v1/users/{userId}/smart-wallets/{smartWalletId}/cards/{cardId}/sensitive` |

A card carries `status`, `currency`, `type` (`physical` or `virtual`), `fundingPolicy` (`SAFE`, `PERSONAL`, or `BOTH`), `fundLifecycle` (`ONE_TIME` or `REPEATABLE`), and `fundedAt` — `null` until the card is first funded. The detail route adds `balanceMinor` and the most recent 100 ledger entries, newest first.

Cards that have been **requested but not yet issued** — the issuance proposal is still awaiting signatures, or the card (typically a physical one) is still being provisioned — appear in the same `cards` list as **reserved cards**, exactly like the personal card list: `status` is `RESERVED` and `isReserved` is `true`. A reserved entry has no card id yet, so its `id` is the issuance proposal id (also exposed as `proposalId`, matching the create response), alongside the requested `cardName`, `cardColor`, `currency`, and `type`, plus `proposalStatus` (`PENDING_APPROVALS`, `PENDING_SIGNATURES`, `READY_TO_EXECUTE`, `EXECUTING`, or `COMPLETED` while provisioning finishes). If an entry sits at `PENDING_SIGNATURES`, the sign-and-submit step from the create flow is still outstanding.

Once issued, the reserved entry is replaced by the real card. A **physical** card then reports `status: PENDING` — it stays `PENDING` through delivery until the holder [activates it](#activate-a-physical-card), so the pre-activation card is always visible in the list: first as `RESERVED`, then as `PENDING`. A reserved entry can also disappear without producing a card — when the proposal expires unsigned or is rejected — so treat a disappearance without a matching new card as a dead request, and check the proposal via `GET /v1/users/{userId}/smart-wallets/proposals/{proposalId}` if in doubt.

<Warning>
  Two amount formats live side by side. The card detail ledger reports `amount` as a **minor-unit string** (`"250000"` = ₦2,500.00), while `GET …/cards/{cardId}/transactions` reports `amount` as a **major-unit number** (`25.5` = \$25.50). Do not feed one into a parser written for the other.
</Warning>

The `/sensitive` route returns only the provider card identity. For the full card number, CVV, expiry, and billing address:

```http theme={null}
POST /v1/users/{userId}/cards/sensitive-data
{
  "identityId": "identity-1",
  "cardId": "card-1"
}
```

<Warning>
  This returns the unmasked PAN and CVV. Treat the response as cardholder data: never log it, never cache it, and pass it straight to the surface that renders it.
</Warning>

***

## Activate a physical card

Two calls. Virtual cards need neither.

```http theme={null}
POST /v1/users/{userId}/cards/{cardId}/activate/request
{
  "pan": "5399838383838381",
  "channel": "sms"
}
```

`channel` is required (`sms` or `email`); `pan` is optional when the number is already known upstream. The response returns `otpId` and `expiresInMinutes`.

```http theme={null}
POST /v1/users/{userId}/cards/{cardId}/activate/confirm
{
  "otpId": "b9fa08b5-46ae-4d85-9ac2-6ca2f4d91234",
  "code": "123456"
}
```

`code` is exactly 6 digits.

***

## Manage a live card

| Action               | Endpoint                                             | Body                                                                 |
| -------------------- | ---------------------------------------------------- | -------------------------------------------------------------------- |
| Freeze / unfreeze    | `PUT /v1/users/{userId}/cards/{cardId}/status`       | `{ "status": "BLOCKED" }` or `"ACTIVE"`                              |
| Set the PIN          | `PUT /v1/users/{userId}/cards/{cardId}/pin`          | `{ "pin": "1234" }`                                                  |
| Reset the PIN        | `POST /v1/users/{userId}/cards/{cardId}/reset`       | `{ "pin": "5678" }`                                                  |
| Set spending limits  | `PUT /v1/users/{userId}/cards/{cardId}/set-limit`    | `{ "totalDailyLimit": 100000, "maxSingleTransactionAmount": 50000 }` |
| Read spending limits | `GET /v1/users/{userId}/cards/{cardId}/limits`       | —                                                                    |
| List transactions    | `GET /v1/users/{userId}/cards/{cardId}/transactions` | —                                                                    |
| Cancel the card      | `PUT /v1/users/{userId}/cards/{cardId}/deactivate`   | —                                                                    |

A PIN is always exactly 4 digits. `GET …/limits` returns the current `totalDailyLimit` and `maxSingleTransactionAmount` alongside `availableDailyLimit` and the provider's caps (`maxTotalDailyLimit`, `maxSingleTransactionLimitCap`) — read it before setting a limit the provider will reject.

`GET …/transactions` accepts `size`, `status` (e.g. `COMPLETED`), and `from` / `to` as ISO 8601 dates.

<Warning>
  `deactivate` permanently cancels the card. It cannot be reversed — freeze with `status: "BLOCKED"` if you only need to stop spending for now.
</Warning>

***

## Card statuses

A card's status is set from two different places, and conflating them is the usual cause of a card that appears stuck.

### What you can set

`PUT /v1/users/{userId}/cards/{cardId}/status` accepts exactly two values:

| Value     | Effect                        |
| --------- | ----------------------------- |
| `BLOCKED` | Freezes the card. Reversible. |
| `ACTIVE`  | Unfreezes a frozen card.      |

Anything else is rejected with `400` before the request leaves BMONI. The values are case-sensitive and upper-case.

<Warning>
  `status: "ACTIVE"` unfreezes a card that is already live. **It does not activate a new card.** Activation is a separate operation — see [Activate a physical card](#activate-a-physical-card). Setting `ACTIVE` on a card that has never been activated is one way to end up looking at `The current status does not allow it`.
</Warning>

### What a card can report

Beyond the two you can set, a card carries statuses that originate with the card issuer and that you can only read:

| Status       | Meaning                               |
| ------------ | ------------------------------------- |
| `pending`    | Issued but not yet activated.         |
| `active`     | Live and able to spend.               |
| `inactive`   | Not able to spend.                    |
| `frozen`     | Temporarily frozen.                   |
| `restricted` | Temporarily restricted by the issuer. |
| `lost`       | Reported lost. The card is blocked.   |
| `stolen`     | Reported stolen.                      |

<Note>
  Read these case-insensitively and treat the set as open. They are the issuer's vocabulary rather than BMONI's, and an issuer can introduce a state without a change on our side. Branch on the ones you handle and fall through to a neutral "unavailable" state for anything else, rather than asserting an exhaustive match.
</Note>

### Permitted transitions are enforced, not published

There is no published transition matrix. The issuer validates each transition at request time against the card's current state, and rejects the ones it does not allow with:

```
The current status does not allow it
```

<Warning>
  Retrying this error cannot succeed. The state will not change on its own, and nothing in the request is at fault. One card was retried four times over sixteen hours against an unchanged state.

  Read the current status first, and if a legitimate transition is being refused, escalate to [developers@bkey.me](mailto:developers@bkey.me) with the `cardId` rather than retrying on a timer.
</Warning>

### Inspecting a card

```http theme={null}
GET /v1/users/{userId}/cards/{cardId}
```

This is the only call that reports a live card's status.

<Warning>
  `GET /v1/users/{userId}/cards/status?workflowId=…` does **not** read a card's status. It polls the *creation workflow* and is only useful between requesting a card and receiving one. The similar name catches people out.
</Warning>

There is no operation that resets a card's state. `POST …/cards/{cardId}/reset` resets the **PIN**, not the status.

***

## Related

* [Transfers](/api-reference/transfers) — the proposal → approve → sign flow in full
* [Integration flow](/api-reference/integration-flow) — every endpoint in call order
* [NGN deposits & withdrawals](/api-reference/ngn-rails) — funding the wallet a card spends from
