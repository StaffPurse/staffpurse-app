> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Transfers — send to another user

> Move stablecoins from a smart wallet to another BMONI user or to any wallet address, and swap between stablecoins inside the wallet, using a proposal → approve → sign flow.

<div className="bmoni-spine">
  <span>Lifecycle</span>
  <a data-stage="1" href="/lifecycle#1-create-the-user">User</a>
  <a data-stage="2" href="/lifecycle#2-provision-the-smart-wallet">Wallet</a>
  <a data-stage="3" href="/lifecycle#3-verify-identity-kyc">KYC</a>
  <a data-stage="4" href="/lifecycle#4-activate-the-rail">Rail</a>
  <a data-stage="5" href="/lifecycle#5-fund-the-wallet">Fund</a>
  <a data-stage="6" href="/lifecycle#6-move-money">Move money</a>
</div>

Once a wallet is active, you can send its balance to another BMONI user, to any wallet address, or swap it into a different stablecoin. All three go through the same **proposal → approve → sign** flow the wallet uses for every value-moving operation.

Nothing moves on the first call. Creating a proposal only records the intent — the transfer executes after the approval threshold is met and the owner key signs.

***

## Send to another user

Four calls, in order.

### 1. Create the transfer proposal

```http theme={null}
POST /v1/users/{userId}/smart-wallets/{smartWalletId}/proposals
{
  "proposal": {
    "type": "TRANSFER",
    "toUserId": "dfda86aa-ae19-49c8-a6c7-0edc743f1cd4",
    "amount": "25.00",
    "currency": "CNGN",
    "description": "Rent split"
  }
}
```

| Field         |                                                                    |
| ------------- | ------------------------------------------------------------------ |
| `type`        | required — `TRANSFER`                                              |
| `toUserId`    | the recipient's `bmoniUserId`. The address is resolved server-side |
| `toAddress`   | alternative to `toUserId` — a `0x`-prefixed 20-byte address        |
| `amount`      | required — decimal string, e.g. `"25.00"`                          |
| `currency`    | required on multi-token wallets, to pick which token to send       |
| `description` | optional — free text, max 500 characters, shown to approvers       |

Pass either `toUserId` or `toAddress`. Passing neither returns a `400`.

<Note>
  The recipient must already hold an active smart wallet **in the currency you are sending**. `toUserId` resolves to the recipient's smart wallet for that currency — the same wallets `GET /v1/users/{recipientId}/smart-wallets/account/wallets` returns — so sending `CNGN` to a user who only has a `USDB` wallet fails with `The recipient does not have an active NGN account to receive this transfer.` That is a `400`, not a missing endpoint. Check the recipient's wallets first, and note that `currency` takes the token code (`CNGN`) while that listing reports the display currency (`NGN`).

  The recipient must also be one of your own users. A `toUserId` belonging to another partner returns a `404`, the same as a user that does not exist.
</Note>

The response carries the proposal `id` you use for the remaining three calls:

```json theme={null}
{
  "data": {
    "proposal": {
      "id": "47665949-8654-4461-b52a-3ef3624b1234",
      "status": "PENDING_APPROVALS"
    }
  }
}
```

#### Shorthand: let the server pick the wallet

If you do not want to name the wallet to debit, `account/send` creates the same proposal and resolves the wallet for you — the account's wallet in `currency`:

```http theme={null}
POST /v1/users/{userId}/smart-wallets/account/send
{
  "toUserId": "dfda86aa-ae19-49c8-a6c7-0edc743f1cd4",
  "amount": "25.00",
  "currency": "CNGN",
  "note": "Rent split"
}
```

`currency` is required when the account holds more than one wallet, and optional when it holds exactly one. `note` becomes the proposal `description`. To name the wallet to debit while still passing a recipient, use `POST /v1/users/{userId}/smart-wallets/fund` with `fromWalletId`.

Both are shortcuts for step 1 only. They return the same proposal, so steps 2 to 4 still apply — nothing moves until the threshold is met and the owner key signs.

### 2. Approve

```http theme={null}
POST /v1/users/{userId}/smart-wallets/proposals/{proposalId}/approve
```

No body required. This records the calling admin's approval vote. `status` moves to `PENDING_SIGNATURES` once the wallet's approval threshold is met.

How many approvals you need depends on the wallet's approval mode — `ANY_ADMIN`, `ADMIN_THRESHOLD`, or `OWNER_APPROVAL`. Read or change it with `PATCH /v1/users/{userId}/smart-wallets/account/approval-policy`.

### 3. Fetch the signing payload

```http theme={null}
GET /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign-payload
```

Returns `hashToSign` — the 32-byte digest you sign — plus a `deadline`, and whichever of `safeTxHash` or `userOpHash` applies to this proposal. The full EIP-712 object is included as `typedData` when the upstream provides it, but you sign `hashToSign`, not `typedData`.

This is only available once the proposal reaches `PENDING_SIGNATURES`, so poll it rather than calling it once — a `404` here usually means the approval threshold has not been met yet, not that the proposal is missing.

### 4. Sign and submit

```http theme={null}
POST /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign
{
  "signature": "0x628f1aff48c9d1f35d45a735eb026db0437c5ed334a94dc7fb0ac86ca32c10bd173a653a7f064c4512244f6fcbefb07e13bfe7368fcacdcc4e6fb153f50050991b"
}
```

Sign `hashToSign` with the wallet owner key — the same key registered as `userOwnerAddress` at wallet creation — and submit the 65-byte hex signature. Poll `GET …/proposals/{proposalId}` for the terminal status.

Use the method that signs a **raw hash**, not the one that signs a *message*: `signingKey.sign()` in ethers, `sign()` in viem, `unsafe_sign_hash()` in `eth-account`. A message-signing method applies the EIP-191 prefix and produces a signature that recovers to a different address, which the backend rejects.

<Warning>
  Signing is where most integrations stall. Read [Sign a proposal](/api-reference/signing) before you write this step — it carries runnable snippets for all three libraries, a known-good test vector you can reproduce offline, and the specific cause of each rejection message.
</Warning>

<Note>
  The signature must come from the registered owner key. Reuse the same SDK instance you used for `initWallet` / `walletAddress`, or the recovered signer will not match the proposal's signer snapshot.
</Note>

To abandon a proposal instead of signing it, `POST …/proposals/{proposalId}/reject` with an optional `{ "reason": "…" }`.

***

## Swap inside the wallet

Same four calls, with a `SWAP` proposal in step 1:

```http theme={null}
POST /v1/users/{userId}/smart-wallets/{smartWalletId}/proposals
{
  "proposal": {
    "type": "SWAP",
    "fromStablecoin": "USDB",
    "toStablecoin": "CNGN",
    "fromAmount": "100.00",
    "slippageBps": 50
  }
}
```

| Field            |                                                                             |
| ---------------- | --------------------------------------------------------------------------- |
| `fromStablecoin` | required — stablecoin to swap out of                                        |
| `toStablecoin`   | required — stablecoin to swap into                                          |
| `fromAmount`     | required — decimal string                                                   |
| `slippageBps`    | optional — acceptable downward drift in basis points, between `1` and `500` |

Supported stablecoins: `USDB`, `CNGN`, `CADC`, `EURe`, `GBPe`, `MEXe`.

For a user-level currency conversion outside the proposal flow, use `POST /v1/users/{userId}/exchange/quote` for a firm time-boxed quote followed by `POST /v1/users/{userId}/exchange/convert`.

***

## Tracking a proposal

| Action                    | Endpoint                                                              |
| ------------------------- | --------------------------------------------------------------------- |
| List a wallet's proposals | `GET /v1/users/{userId}/smart-wallets/{smartWalletId}/proposals`      |
| Read one proposal         | `GET /v1/users/{userId}/smart-wallets/proposals/{proposalId}`         |
| Reject a proposal         | `POST /v1/users/{userId}/smart-wallets/proposals/{proposalId}/reject` |

`status` progresses `PENDING_APPROVALS` → `PENDING_SIGNATURES` → `COMPLETED`. A `FAILED` proposal can be retried by calling `approve` again, which restarts the workflow.

***

## Related

* [Integration flow](/api-reference/integration-flow#wallet-home-operations) — every wallet-home endpoint in one table
* [NGN deposits & withdrawals](/api-reference/ngn-rails) — the same proposal → sign pattern, applied to a bank payout
* [Rails](/api-reference/rails) — which currencies and rails are available per region
