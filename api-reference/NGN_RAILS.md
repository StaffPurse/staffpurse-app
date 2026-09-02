> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# NGN — deposits & bank withdrawals

> Fund a wallet from a Nigerian virtual account, and withdraw NGN or USD to any Nigerian bank account via a verify → register → offramp flow.

<div className="bmoni-spine">
  <span>Lifecycle</span>
  <a data-stage="1" href="/lifecycle#1-create-the-user">User</a>
  <a data-stage="2" href="/lifecycle#2-provision-the-smart-wallet">Wallet</a>
  <a data-stage="3" href="/lifecycle#3-verify-identity-kyc">KYC</a>
  <a data-stage="4" href="/lifecycle#4-activate-the-rail">Rail</a>
  <a data-stage="5" href="/lifecycle#5-fund-the-wallet">Fund</a>
  <a data-stage="6" href="/lifecycle#6-move-money">Move money</a>
</div>

After [Nigeria onboarding](/api-reference/kyc-nga-requirements) is `active`, the wallet holds `CNGN` and money moves in two directions: **in** through a Nigerian virtual account, and **out** to any Nigerian bank account.

***

## Deposits (NGN in)

Incoming NGN bank transfers land on a virtual account and are credited to the smart wallet as `CNGN`.

The virtual account itself is created during [Nigeria onboarding](/api-reference/kyc-nga-requirements) — `POST /onboarding/start-nigeria` is what issues it. This call points its deposits at a smart wallet:

```http theme={null}
POST /v1/users/{userId}/smart-wallets/{smartWalletId}/onramp/vba/nigeria
```

The bank account must belong to the calling user, who must be an active admin of the wallet.

Read the account details back — the number the user actually transfers to — with:

```http theme={null}
GET /v1/users/{userId}/bank-accounts/deposit-accounts/NGN
```

To stop routing deposits to this wallet, `DELETE` the same `onramp/vba/nigeria` path.

***

## Withdrawals (NGN / USD → Nigerian bank)

Three calls, in order. Do not skip the verify step — it is what gives you the exact account holder name the registration call requires.

### 1. Look up the bank code

```http theme={null}
GET /v1/users/{userId}/bank-accounts/nigerian-banks
```

Returns every supported bank with its name and CBN code. Use both verbatim in the next two calls.

### 2. Verify the account number

```http theme={null}
POST /v1/users/{userId}/bank-accounts/verify-nigerian-account
{
  "accountNumber": "0123456789",
  "bankCode": "058"
}
```

Returns the registered account holder name. A `404` means no account matches that number and bank code — surface it and let the user correct the number rather than pushing on.

### 3. Register the withdrawal account

```http theme={null}
POST /v1/users/{userId}/bank-accounts/withdrawal-accounts/nigeria
{
  "accountNumber": "0123456789",
  "bankCode": "058",
  "bankName": "Guaranty Trust Bank",
  "accountHolderName": "Jane Doe"
}
```

| Field               |                                                                 |
| ------------------- | --------------------------------------------------------------- |
| `accountNumber`     | required — NUBAN, exactly 10 digits                             |
| `bankCode`          | required — CBN code from `nigerian-banks`                       |
| `bankName`          | required — full bank name as returned by `nigerian-banks`       |
| `accountHolderName` | required — the exact name returned by `verify-nigerian-account` |

Get-or-create: calling it again with the same account returns the existing record instead of duplicating it. The response carries the `id` you pass as `bankAccountId` below.

### 4. Create the offramp

```http theme={null}
POST /v1/users/{userId}/smart-wallets/{smartWalletId}/offramp/nigeria
{
  "bankAccountId": "9c1f7a20-5d3e-4b8a-9f21-77c2e5a41234",
  "fromAmount": "100.00"
}
```

| Field           |                                                                                     |
| --------------- | ----------------------------------------------------------------------------------- |
| `bankAccountId` | required — UUID of a registered Nigerian withdrawal account belonging to the caller |
| `fromAmount`    | required — decimal string, e.g. `"100.00"`                                          |

Source currency can be `CNGN` (sent directly) or `USDB` (auto-swapped to NGN first). The caller must be an active admin of the smart wallet.

This returns a **proposal**, not a completed payout:

```json theme={null}
{
  "data": {
    "proposalId": "47665949-8654-4461-b52a-3ef3624b1234",
    "status": "PENDING_APPROVALS",
    "quote": { }
  }
}
```

### 5. Sign the proposal

`status` moves `PENDING_APPROVALS` → `PENDING_SIGNATURES` once the approval threshold is met, then `COMPLETED` after the on-chain execution and the off-chain payout both succeed.

```http theme={null}
GET  /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign-payload
POST /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign
```

Sign the EIP-712 payload with the wallet owner key via `bmoni_embedded_sdk` — the same key registered as `userOwnerAddress` at wallet creation — and submit the hex signature. Poll `GET …/proposals/{proposalId}` for the terminal status.

<Note>
  The signature must come from the registered owner key. Reuse the same SDK instance you used for `initWallet` / `walletAddress`, or the recovered signer will not match the proposal's signer snapshot.
</Note>

***

## Related

* [Transfers](/api-reference/transfers) — the same proposal → sign pattern, applied to a user-to-user send or an in-wallet swap
* [KYC — Nigeria](/api-reference/kyc-nga-requirements) — what onboarding requires, including the sandbox test BVN
* [USD virtual bank account](/api-reference/usd-vba) — the other rail available to Nigerian users
* [Integration flow](/api-reference/integration-flow#wallet-home-operations) — every wallet-home endpoint in one table
