import 'dart:io';

void main() {
  var file = File('lib/services/onboarding_service.dart');
  var content = file.readAsStringSync();
  
  var oldInit = '''
      String userOwnerAddress;
      if (await BmoniEmbeddedSdk.hasWallet()) {
        userOwnerAddress = (await BmoniEmbeddedSdk.walletAddress())!;
      } else {
        userOwnerAddress = await BmoniEmbeddedSdk.initWallet();
      }
''';

  var newInit = '''
      String userOwnerAddress;
      if (await BmoniEmbeddedSdk.hasWallet()) {
        userOwnerAddress = (await BmoniEmbeddedSdk.walletAddress())!;
      } else {
        // HACK: If the app was uninstalled/reinstalled, the native Android Keystore
        // often retains the secure hardware keys even though FlutterSecureStorage is wiped.
        // The BMONI SDK fails to catch the KeyAlreadyExistsException natively, which force-closes the app!
        // We temporarily disable the PIN requirement to force-delete the native wallet before re-initializing it.
        BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: false);
        try {
          await BmoniEmbeddedSdk.deleteWallet();
        } catch (_) {}
        BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);

        userOwnerAddress = await BmoniEmbeddedSdk.initWallet();
      }
''';

  content = content.replaceFirst(oldInit, newInit);
  file.writeAsStringSync(content);
}
