Exact signing call signature for the sign-and-submit step in card issuance. I flagged this as never independently verified back when we wrote ARCHITECTURE.md §6 — still true

> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Signing

> Sign messages and transaction hashes with the on-device wallet.

<div className="bmoni-spine">
  <span>Lifecycle</span>
  <a data-stage="1" href="/lifecycle#1-create-the-user">User</a>
  <a data-stage="2" href="/lifecycle#2-provision-the-smart-wallet">Wallet</a>
  <a data-stage="3" href="/lifecycle#3-verify-identity-kyc">KYC</a>
  <a data-stage="4" href="/lifecycle#4-activate-the-rail">Rail</a>
  <a data-stage="5" href="/lifecycle#5-fund-the-wallet">Fund</a>
  <a data-stage="6" href="/lifecycle#6-move-money">Move money</a>
</div>

The SDK exposes two signing methods. Both require a provisioned wallet, and both verify the PIN before calling the native layer when `requirePin: true`.

All signatures are:

* `0x`-prefixed 130-character hex strings
* Recoverable ECDSA in `r(32) ‖ s(32) ‖ v(1)` format
* Low-s normalised (EIP-2 compliant)
* `v ∈ {27, 28}` — verifiable with `ecrecover`

***

## Sign a personal message (EIP-191)

`signMessage` prepends the `\x19Ethereum Signed Message:\n{length}` prefix before hashing and signing. This matches the `personal_sign` RPC method used by SIWE, login challenges, and most wallet connect flows.

```dart theme={null}
final String signature = await BmoniEmbeddedSdk.signMessage(
  'Welcome to BMONI!',
  pin: '123456',
);
// 0x...130 chars...
```

When `requirePin: false`, omit the `pin` argument:

```dart theme={null}
BmoniEmbeddedSdk.initialize(requirePin: false);
final String sig = await BmoniEmbeddedSdk.signMessage('Welcome to BMONI!');
```

***

## Sign a 32-byte hash

`signTransactionHash` signs a **pre-computed** 32-byte digest directly, without adding any prefix. Use this for:

* ERC-4337 `userOpHash`
* EIP-712 structured-data digests
* Raw Ethereum transaction hashes
* Any other 32-byte payload you've already hashed yourself

```dart theme={null}
final String signature = await BmoniEmbeddedSdk.signTransactionHash(
  '0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8',
  pin: '123456',
);
```

The argument must be a `0x`-prefixed 64-hex-character (32-byte) string. Anything else throws `signInvalidHash`.

***

## Server-side verification

Signatures are ECDSA-recoverable. Your backend (or a smart contract) only needs the address from `initWallet()`:

```solidity theme={null}
// Solidity
address recovered = ecrecover(hash, v, r, s);
require(recovered == expectedAddress, "invalid signature");
```

```typescript theme={null}
// ethers.js / viem
import { verifyMessage } from 'ethers';
const recovered = verifyMessage('Welcome to BMONI!', signature);
console.log(recovered === walletAddress); // true
```

***

## Gating pattern

A common pattern is to ask for the PIN only when `requirePin` is `true`, and skip the prompt otherwise:

```dart theme={null}
Future<String?> _sign(String message) async {
  String? pin;

  if (BmoniEmbeddedSdk.requirePin) {
    pin = await showPinDialog(context);
    if (pin == null) return null; // user dismissed
  }

  return BmoniEmbeddedSdk.signMessage(message, pin: pin);
}
```

***

## Prerequisites checklist

Before calling either signing method you need:

1. A provisioned wallet (`initWallet()` succeeded or `hasWallet()` is `true`)
2. A PIN set (`hasPin()` is `true`) — only when `requirePin: true`

Calling a signing method without satisfying these will throw `pinNotSet` or result in a native error.
