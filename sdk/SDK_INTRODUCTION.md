> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Introduction

> bmoni_embedded_sdk — on-device Ethereum wallet provisioning and signing for Flutter.

`bmoni_embedded_sdk` is a Flutter plugin that exposes the **BMONISigner** native SDKs for Android and iOS. It lets you provision a self-custodied secp256k1 wallet and produce EIP-191 / EIP-712 compatible signatures entirely within the device's secure hardware boundary.

<Note>
  Building with React Native instead? The same SDK ships [on npm under the same name](/sdk-react-native/introduction), with the same API surface and error codes.
</Note>

<Info>
  **Security first.** Private keys are generated on-device, encrypted with a platform-managed wrapping key (Android Keystore on Android, Secure Enclave on iOS), and persisted only as ciphertext. Plaintext keys never leave the secure boundary and are zeroized in RAM after each operation.
</Info>

***

## What it does

| Capability                        | API                                                      |
| --------------------------------- | -------------------------------------------------------- |
| Provision a wallet                | `initWallet()`                                           |
| Read the cached address           | `walletAddress()`, `hasWallet()`                         |
| Delete the wallet                 | `deleteWallet(pin:)`                                     |
| Set / change / remove PIN         | `setPin`, `changePin`, `removePin`, `matchPin`, `hasPin` |
| Sign a personal message (EIP-191) | `signMessage(message, pin:)`                             |
| Sign a 32-byte hash               | `signTransactionHash(hashHex, pin:)`                     |
| Configure PIN policy              | `BmoniEmbeddedSdk.initialize(pinLength:, requirePin:)`   |

All signatures are returned as `0x`-prefixed 130-character hex strings in recoverable `r(32) ‖ s(32) ‖ v(1)` format with `v ∈ {27, 28}` and low-s normalisation (EIP-2 compliant), ready to be verified server-side with `ecrecover`.

***

## Platform support

| Android                         | iOS                          |
| ------------------------------- | ---------------------------- |
| ✅ Android Keystore (minSdk 24+) | ✅ Secure Enclave (iOS 13.0+) |

***

## Architecture

`BmoniEmbeddedSdk` is a **static facade** — you never instantiate it. All methods are `static` and can be called from anywhere after a single `initialize` call.

```
BmoniEmbeddedSdk (Dart facade)
        │
        ├── PIN layer (flutter_secure_storage + PBKDF2-HMAC-SHA256)
        │
        └── Method channel ──► BMONISigner (native)
                                    ├── Android Keystore
                                    └── iOS Secure Enclave
```

The Dart layer adds:

* **Address caching** — `initWallet()` result is persisted in `flutter_secure_storage` so you can read it back after the app restarts without re-provisioning.
* **PIN gating** — when `requirePin: true`, the PIN digest is verified in Dart before forwarding to the native plugin.

***

## Links

* [pub.dev package page](https://pub.dev/packages/bmoni_embedded_sdk)
* [GitHub repository](https://github.com/bkey-inc/bmoni_embedded_sdk)
* Next: [Installation](/sdk/installation)
