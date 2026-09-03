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
    required String dateOfBirth,
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

      // 1.5 Activate KYC
      await BmoniApi.activateKycOnly(
        userId: bmoniUserId,
        dateOfBirth: dateOfBirth,
        bvn: bvn,
      );

      // 2. Set Wallet PIN and Provision Wallet on-device
      if (!await BmoniEmbeddedSdk.hasPin()) {
        await BmoniEmbeddedSdk.setPin(pin);
      }
      
      String walletAddress;
      if (await BmoniEmbeddedSdk.hasWallet()) {
        walletAddress = (await BmoniEmbeddedSdk.walletAddress())!;
      } else {
        walletAddress = await BmoniEmbeddedSdk.initWallet();
      }

      // 3. Save Business mapping to Supabase
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('business').insert({
        'owner_id': userId,
        'owner_bmoni_user_id': bmoniUserId,
        'owner_wallet_id': walletAddress, // Or the actual Smart Wallet UUID if different
        'name': businessName,
      });

    } catch (e) {
      // Rethrow to be caught by UI
      throw Exception('Onboarding failed: $e');
    }
  }
}
