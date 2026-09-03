import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'bmoni_api.dart';

class OnboardingService {
  final _supabase = Supabase.instance.client;

  Future<void> onboardOwner({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String bvn,
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

      // 4. Start Nigeria Onboarding (Auto-verifies BVN and provisions NGN rail)
      final startRes = await BmoniApi.startNigeriaOnboarding(
        userId: bmoniUserId,
        bvn: bvn,
        ngnWalletAddress: userOwnerAddress,
        ngnWalletIndex: 0,
      );
      

      // 5. Save Business mapping to Supabase
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('business').insert({
        'owner_id': userId,
        'owner_bmoni_user_id': bmoniUserId,
        'owner_wallet_id': smartWalletId,
        'name': businessName,
      });

    } catch (e) {
      throw Exception('Onboarding failed: $e');
    }
  }
}
