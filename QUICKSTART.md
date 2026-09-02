> ## Documentation Index
> Fetch the complete documentation index at: https://bkey.mintlify.site/llms.txt
> Use this file to discover all available pages before exploring further.

# Quickstart

> Add an embedded Ethereum wallet with a signing-gated PIN to a Flutter app in under 10 minutes.

This guide walks you through the most common integration path: provision an on-device wallet, set a PIN, and produce your first signature. It uses all three packages together, but each one is optional — skip the steps that don't apply to your use-case.

***

## Prerequisites

* Flutter `>=3.3.0` / Dart `>=3.11`
* Android `minSdk 24+` or iOS `13.0+`

***

<Steps>
  <Step title="Add the packages">
    Add all three packages to `pubspec.yaml`:

    ```yaml theme={null}
    dependencies:
      bmoni_embedded_sdk: ^0.0.1
      bkey_uikit: ^0.0.1
      bmoni_embedded_wallets_cards: ^0.0.1
    ```

    Then fetch them:

    ```bash theme={null}
    flutter pub get
    ```
  </Step>

  <Step title="Apply the BMONI theme">
    Wrap your app root with `BMoniTheme.darkTheme()` (or `lightTheme()`) so every widget in the tree picks up the correct colours and typography automatically.

    ```dart theme={null}
    import 'package:bkey_uikit/bkey_uikit.dart';
    import 'package:flutter/material.dart';

    void main() {
      BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);
      runApp(
        MaterialApp(
          theme: BMoniTheme.darkTheme(),
          home: const MyHomePage(),
        ),
      );
    }
    ```
  </Step>

  <Step title="Initialise the SDK">
    Call `BmoniEmbeddedSdk.initialize` once — before `runApp` is the recommended place. The defaults are `pinLength: 6` and `requirePin: true`.

    ```dart theme={null}
    import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';

    void main() {
      BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);
      runApp(const MyApp());
    }
    ```
  </Step>

  <Step title="Provision a wallet">
    On first launch, call `initWallet()` to generate a secp256k1 keypair inside the device's secure hardware. The returned EIP-55 address is automatically cached in `flutter_secure_storage`.

    ```dart theme={null}
    final String address = await BmoniEmbeddedSdk.hasWallet()
        ? (await BmoniEmbeddedSdk.walletAddress())!
        : await BmoniEmbeddedSdk.initWallet();

    print('Wallet: $address');
    ```
  </Step>

  <Step title="Set a PIN">
    The PIN gates future signing operations. It is stored only as a PBKDF2-HMAC-SHA256 digest — the raw value never touches disk.

    ```dart theme={null}
    if (!await BmoniEmbeddedSdk.hasPin()) {
      await BmoniEmbeddedSdk.setPin('123456');
    }
    ```
  </Step>

  <Step title="Sign a message">
    Use `signMessage` for EIP-191 personal-sign flows (SIWE, login challenges):

    ```dart theme={null}
    final String sig = await BmoniEmbeddedSdk.signMessage(
      'Welcome to BMONI!',
      pin: '123456',
    );
    // sig is 0x-prefixed, 130-char hex: r(32) || s(32) || v(1)
    ```

    Or `signTransactionHash` for a pre-computed 32-byte digest (ERC-4337 userOpHash, EIP-712, raw tx hash):

    ```dart theme={null}
    final String sig = await BmoniEmbeddedSdk.signTransactionHash(
      '0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8',
      pin: '123456',
    );
    ```
  </Step>

  <Step title="Handle errors">
    Wrap SDK calls in a `try/catch` and branch on `BmoniSignerErrorCode`:

    ```dart theme={null}
    try {
      await BmoniEmbeddedSdk.initWallet();
    } on BmoniSignerException catch (e) {
      switch (e.errorCode) {
        case BmoniSignerErrorCode.walletAlreadyExists:
          // Show a re-provision dialog.
          break;
        case BmoniSignerErrorCode.pinMismatch:
          // Ask the user to re-enter their PIN.
          break;
        default:
          debugPrint('SDK error: ${e.message}');
      }
    }
    ```

    See the full [error reference](/sdk/error-handling) for all codes.
  </Step>

  <Step title="Render a wallet card (optional)">
    If you also have `bmoni_embedded_wallets_cards`, wire a notifier and drop in the card widget:

    ```dart theme={null}
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';

    // In your Riverpod provider setup:
    final walletListProvider =
        StateNotifierProvider<EmbeddedWalletListNotifier, EmbeddedWalletListState>(
      (ref) => EmbeddedWalletListNotifier(
        walletDataSource: ref.watch(walletDataSourceProvider),
        storage: ref.watch(walletStorageProvider),
      ),
    );

    // In your widget:
    EmbeddedWalletCard(
      wallet: wallet,
      isBalanceHidden: false,
      onToggleHideBalance: () { /* toggle in your state */ },
    );
    ```

    See the full [wallets & cards guide](/wallets/introduction) for the complete wiring.
  </Step>
</Steps>

***

## Next steps

<CardGroup cols={2}>
  <Card title="SDK configuration" href="/sdk/configuration">
    Customise PIN length and the `requirePin` gate.
  </Card>

  <Card title="PIN management" href="/sdk/pin-management">
    Change, verify, and remove PINs.
  </Card>

  <Card title="Design tokens" href="/uikit/design-tokens">
    Use BMONI colours and typography in your own widgets.
  </Card>

  <Card title="Wallet card widgets" href="/wallets/widgets">
    Full API for `EmbeddedWalletCard` and the transactions section.
  </Card>
</CardGroup>
