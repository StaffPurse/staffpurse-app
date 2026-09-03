import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'bmoni_api.dart';

class OnboardingService {
  final _supabase = Supabase.instance.client;

  // Stage 1 & 2: Create User & Provision Smart Wallet
  Future<Map<String, String>> setupProfileAndWallet({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String businessName,
    required String pin,
  }) async {
    try {
      // 1. Create User in BMONI
      final bmoniUserId = await BmoniApi.createUserOnly(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
      );

      // 2. Set Wallet PIN and Provision Wallet on-device
      if (!await BmoniEmbeddedSdk.hasPin()) {
        await BmoniEmbeddedSdk.setPin(pin);
      }
      
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

      // 3. Register Smart Wallet with BMONI
      final challenge = await BmoniApi.getOwnerProofChallenge(
        userId: bmoniUserId, 
        userOwnerAddress: userOwnerAddress
      );
      final signature = await BmoniEmbeddedSdk.signMessage(challenge['eip191Message'], pin: pin);
      final walletResult = await BmoniApi.createManagedWallet(
        userId: bmoniUserId,
        userOwnerAddress: userOwnerAddress,
        challengeId: challenge['challengeId'],
        signature: signature,
      );
      final smartWalletId = walletResult['id'];

      // 4. Save Business mapping to Supabase
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('business').insert({
        'owner_id': userId,
        'owner_bmoni_user_id': bmoniUserId,
        'owner_wallet_id': smartWalletId,
        'name': businessName,
      });

      return {
        'bmoniUserId': bmoniUserId,
        'smartWalletId': smartWalletId,
        'userOwnerAddress': userOwnerAddress,
      };
    } catch (e) {
      if (e.toString().contains('409') || e.toString().toLowerCase().contains('already exists')) {
        throw Exception('This phone or email is already registered with BMONI.\n\nIf you already have an account, please click the Log Out button in the top right, then Login with your existing credentials instead of creating a new one.');
      }
      throw Exception('Setup failed: $e');
    }
  }

  // Stage 3 & 4: KYC & Activate Rail
  Future<void> activateKyc({
    required String bmoniUserId,
    required String bvn,
  }) async {
    try {
      // We must get the local wallet address we created in Stage 2
      final userOwnerAddress = (await BmoniEmbeddedSdk.walletAddress())!;

      // Start Nigeria Onboarding (Auto-verifies BVN and provisions NGN rail)
      await BmoniApi.startNigeriaOnboarding(
        userId: bmoniUserId,
        bvn: bvn,
        ngnWalletAddress: userOwnerAddress,
        ngnWalletIndex: 0,
      );
    } catch (e) {
      throw Exception('KYC Activation failed: $e');
    }
  }
}
