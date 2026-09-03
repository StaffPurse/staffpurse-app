import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'bmoni_api.dart';
import 'crash_log.dart';

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
      // 0. Guard the PIN before spending any API calls — the SDK throws
      //    pinInvalid for any length other than 6, and a late failure here
      //    would have already created a BMONI user we don't want.
      if (pin.length != 6) {
        throw const BmoniSignerException(
          errorCode: BmoniSignerErrorCode.pinInvalid,
          message: 'PIN must be exactly 6 digits',
        );
      }

      // 1. Create User in BMONI
      final bmoniUserId = await BmoniApi.createUserOnly(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
      );
      await CrashLog.write('onboarding: user created ($bmoniUserId)');

      // 2. Set Wallet PIN and Provision Wallet on-device
      if (!await BmoniEmbeddedSdk.hasPin()) {
        await BmoniEmbeddedSdk.setPin(pin);
      }
      await CrashLog.write('onboarding: pin set');

      String userOwnerAddress;
      if (await BmoniEmbeddedSdk.hasWallet()) {
        userOwnerAddress = (await BmoniEmbeddedSdk.walletAddress())!;
      } else {
        try {
          userOwnerAddress = await BmoniEmbeddedSdk.initWallet();
        } on BmoniSignerException catch (e) {
          if (e.errorCode != BmoniSignerErrorCode.walletAlreadyExists) {
            rethrow;
          }
          // Stale wallet from a previous install: the Dart-side address cache
          // is gone but the encrypted key file survived on disk, so
          // initWallet refuses. The old address is unrecoverable through the
          // SDK, and this flow is always a fresh BMONI user, so deleting and
          // re-provisioning is safe. The PIN gate is temporarily disabled so
          // the delete works even if a stale PIN from an earlier install
          // lingers in secure storage.
          await CrashLog.write('onboarding: stale wallet found, re-provisioning');
          BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: false);
          try {
            await BmoniEmbeddedSdk.deleteWallet();
          } finally {
            BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);
          }
          userOwnerAddress = await BmoniEmbeddedSdk.initWallet();
        }
      }
      await CrashLog.write('onboarding: wallet ready ($userOwnerAddress)');

      // 3. Register Smart Wallet with BMONI
      final challenge = await BmoniApi.getOwnerProofChallenge(
        userId: bmoniUserId,
        userOwnerAddress: userOwnerAddress,
      );
      final eip191Message = challenge['eip191Message'] as String?;
      if (eip191Message == null || eip191Message.isEmpty) {
        throw Exception(
          'BMONI did not return an EIP-191 challenge message: $challenge',
        );
      }
      final signature = await BmoniEmbeddedSdk.signMessage(eip191Message, pin: pin);
      await CrashLog.write('onboarding: owner-proof challenge signed');

      final walletResult = await BmoniApi.createManagedWallet(
        userId: bmoniUserId,
        userOwnerAddress: userOwnerAddress,
        challengeId: challenge['challengeId'],
        signature: signature,
      );
      final smartWalletId = walletResult['id'];
      await CrashLog.write('onboarding: smart wallet registered ($smartWalletId)');

      // 4. Save Business mapping to Supabase
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('business').insert({
        'owner_id': userId,
        'owner_bmoni_user_id': bmoniUserId,
        'owner_wallet_id': smartWalletId,
        'name': businessName,
      });
      await CrashLog.write('onboarding: business row saved');

      return {
        'bmoniUserId': bmoniUserId,
        'smartWalletId': smartWalletId,
        'userOwnerAddress': userOwnerAddress,
      };
    } catch (e) {
      await CrashLog.write('onboarding: FAILED -> $e');
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
      await CrashLog.write('kyc: activating rail for $bmoniUserId');

      // Start Nigeria Onboarding (Auto-verifies BVN and provisions NGN rail)
      await BmoniApi.startNigeriaOnboarding(
        userId: bmoniUserId,
        bvn: bvn,
        ngnWalletAddress: userOwnerAddress,
        ngnWalletIndex: 0,
      );
      await CrashLog.write('kyc: rail activation submitted');
    } catch (e) {
      await CrashLog.write('kyc: FAILED -> $e');
      throw Exception('KYC Activation failed: $e');
    }
  }
}