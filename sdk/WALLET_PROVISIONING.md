How you actually create the owner's on-device wallet — this is Prompt 2 in PROMPT.md and I've never seen its real content

> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Wallet provisioning

> Create, read, and delete an on-device Ethereum wallet.

<div className="bmoni-spine">
  <span>Lifecycle</span>
  <a data-stage="1" href="/lifecycle#1-create-the-user">User</a>
  <a data-stage="2" href="/lifecycle#2-provision-the-smart-wallet">Wallet</a>
  <a data-stage="3" href="/lifecycle#3-verify-identity-kyc">KYC</a>
  <a data-stage="4" href="/lifecycle#4-activate-the-rail">Rail</a>
  <a data-stage="5" href="/lifecycle#5-fund-the-wallet">Fund</a>
  <a data-stage="6" href="/lifecycle#6-move-money">Move money</a>
</div>

## Overview

A wallet is a secp256k1 keypair generated inside the device's secure hardware. The SDK stores the **encrypted** private key on-device and returns the EIP-55 checksummed address — the only piece of data you need to share with your backend.

<Info>
  The native BMONISigner layer only returns the address at the moment of provisioning. The Dart facade caches it in `flutter_secure_storage` automatically, so you can read it back at any time.
</Info>

***

## Check whether a wallet exists

```dart theme={null}
final bool exists = await BmoniEmbeddedSdk.hasWallet();
```

***

## Provision a new wallet

```dart theme={null}
try {
  final String address = await BmoniEmbeddedSdk.initWallet();
  print('Wallet address: $address');
  // address is EIP-55 checksummed, e.g. 0xAbC...123
} on BmoniSignerException catch (e) {
  if (e.errorCode == BmoniSignerErrorCode.walletAlreadyExists) {
    // A wallet is already on disk — see "Re-provisioning" below.
  }
}
```

`initWallet` throws `walletAlreadyExists` if the native layer already holds an encrypted key. You must delete it first before provisioning again.

***

## Read the cached address

```dart theme={null}
final String? address = await BmoniEmbeddedSdk.walletAddress();
if (address != null) {
  // Wallet is provisioned.
}
```

The typical startup pattern:

```dart theme={null}
final String address = await BmoniEmbeddedSdk.hasWallet()
    ? (await BmoniEmbeddedSdk.walletAddress())!
    : await BmoniEmbeddedSdk.initWallet();
```

***

## Delete a wallet

`deleteWallet` removes the encrypted private key from device storage. It is idempotent at the native layer.

```dart theme={null}
await BmoniEmbeddedSdk.deleteWallet(pin: '123456');
// The address cache is also wiped automatically.
```

When `requirePin` is `false`, omit the `pin` argument:

```dart theme={null}
BmoniEmbeddedSdk.initialize(requirePin: false);
await BmoniEmbeddedSdk.deleteWallet();
```

<Warning>
  Deletion is **permanent and irreversible from this device**. The on-chain address is unrecoverable once the key is deleted.
</Warning>

***

## Re-provisioning (recovery flow)

If `initWallet` throws `walletAlreadyExists` but `walletAddress()` returns `null`, the native wallet exists but the Dart-side address cache is missing (e.g., the app was reinstalled). The only recovery path is to delete the existing wallet and provision a new one:

```dart theme={null}
// This is destructive — the old address becomes unrecoverable.
try {
  // Temporarily disable the PIN gate so we can delete without a known PIN.
  BmoniEmbeddedSdk.initialize(requirePin: false);
  await BmoniEmbeddedSdk.deleteWallet();
  BmoniEmbeddedSdk.initialize(requirePin: true); // restore

  final String newAddress = await BmoniEmbeddedSdk.initWallet();
  print('Re-provisioned: $newAddress');
} on BmoniSignerException catch (e) {
  print('Recovery failed: ${e.message}');
}
```

Always show a confirmation dialog before executing this flow — the old address is gone after deletion.
