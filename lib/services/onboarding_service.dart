import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'bmoni_api.dart';
import 'crash_log.dart';

class OnboardingService {
  final _supabase = Supabase.instance.client;
  static const _storage = FlutterSecureStorage();

  static bool _isDuplicateError(Object e) {
    final raw = e.toString().toLowerCase();
    return raw.contains('409') ||
        raw.contains('already exists') ||
        raw.contains('23505') ||
        raw.contains('duplicate');
  }

  /// Creates a BMONI user, or recovers the one a previous failed attempt
  /// left behind instead of failing with "already registered".
  ///
  /// Orphaned users happen whenever the flow dies after user creation but
  /// before the business row is saved (wrong phone, wallet crash, network
  /// drop, …). Recovery matches on the Supabase account + email so a retry
  /// with a corrected phone number keeps working.
  Future<String> _createOrRecoverBmoniUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
  }) async {
    // Pre-flight mirrors the UI validator: a malformed phone must never
    // create a user we can't link to anything.
    final cleanPhone = phoneNumber.replaceAll(' ', '');
    if (!RegExp(r'^\+234\d{10}$').hasMatch(cleanPhone)) {
      throw Exception('Phone must be in +234 format, e.g. +2348012345678');
    }

    final supabaseUid = _supabase.auth.currentUser?.id ?? '';
    try {
      final id = await BmoniApi.createUserOnly(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: cleanPhone,
      );
      await _persistBmoniUser(id, email, cleanPhone, supabaseUid);
      await CrashLog.write('onboarding: BMONI user created ($id)');
      return id;
    } on Exception catch (e) {
      if (!_isDuplicateError(e)) rethrow;

      // A previous attempt on this device already created the user. Reuse it
      // if it belongs to this Supabase account on this device — the email or
      // phone may have been corrected between attempts, and requiring an exact
      // email match is what burned emails in earlier versions. The keys live in
      // per-install secure storage, so an orphan stored under the same Supabase
      // account almost certainly belongs to this onboarding attempt.
      final storedId = await _storage.read(key: 'owner_bmoni_user_id');
      final storedUid = await _storage.read(key: 'owner_supabase_uid');
      if (storedId != null && storedId.isNotEmpty && storedUid == supabaseUid) {
        await CrashLog.write(
          'onboarding: adopting stored orphan user ($storedId) for this account',
        );
        return _adoptExistingUser(storedId, email, cleanPhone, supabaseUid);
      }

      // The duplicate response usually names the existing user — take it.
      final existingId = RegExp(
        r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
      ).firstMatch(e.toString())?.group(0);
      if (existingId != null) {
        return _adoptExistingUser(existingId, email, cleanPhone, supabaseUid);
      }

      throw Exception(
        'This email or phone is already registered on another account. '
        'Use a different email and phone to create a new account, or log in '
        'if you already completed setup.',
      );
    }
  }

  Future<void> _persistBmoniUser(
    String userId,
    String email,
    String phone,
    String supabaseUid,
  ) async {
    await _storage.write(key: 'owner_bmoni_user_id', value: userId);
    await _storage.write(key: 'owner_bmoni_email', value: email.toLowerCase());
    await _storage.write(key: 'owner_bmoni_phone', value: phone);
    await _storage.write(key: 'owner_supabase_uid', value: supabaseUid);
  }

  /// Adopts an existing BMONI user (same Supabase account + email, or one the
  /// duplicate response named) and reactivates it in case it was deleted
  /// earlier. Reactivation is a no-op on an active user.
  Future<String> _adoptExistingUser(
    String userId,
    String email,
    String phone,
    String supabaseUid,
  ) async {
    await _persistBmoniUser(userId, email, phone, supabaseUid);
    await CrashLog.write('onboarding: recovered existing BMONI user ($userId)');
    try {
      await BmoniApi.reactivateUser(userId: userId);
      await CrashLog.write('onboarding: reactivated BMONI user ($userId)');
    } catch (e) {
      await CrashLog.write('onboarding: reactivate skipped: $e');
    }
    return userId;
  }

  /// Best-effort lookup of an existing smart wallet when registration reports
  /// a duplicate (a previous attempt created it but the flow died).
  Future<String?> _recoverWalletId(String bmoniUserId) async {
    try {
      final status = await BmoniApi.getOnboardingStatus(userId: bmoniUserId);
      String? found;
      void walk(dynamic node) {
        if (found != null) return;
        if (node is Map) {
          for (final entry in node.entries) {
            final key = entry.key.toString().toLowerCase();
            if ((key.contains('wallet') && key.contains('id')) ||
                key == 'smartwalletid' ||
                key == 'walletid') {
              final value = entry.value?.toString() ?? '';
              if (value.isNotEmpty && value != 'null') {
                found = value;
                return;
              }
            }
            walk(entry.value);
          }
        } else if (node is List) {
          for (final item in node) {
            walk(item);
          }
        }
      }

      walk(status);
      if (found != null) {
        await CrashLog.write('onboarding: recovered existing smart wallet ($found)');
      }
      return found;
    } catch (e) {
      return null;
    }
  }

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

      // The BMONI signer native library ships only for 64-bit ARM. On any
      // other ABI initWallet() throws UnsatisfiedLinkError — an Error the
      // SDK plugin deliberately lets crash the whole process, which Dart
      // cannot catch. Fail fast BEFORE any API calls so an unsupported
      // device gets a readable message and no orphan BMONI user is created.
      final arch = deviceArch();
      if (!arch.contains('arm64')) {
        await CrashLog.write('onboarding: UNSUPPORTED CPU ARCH ($arch) — native signer is arm64-only');
        throw Exception(
          'This build of StaffPurse only supports 64-bit ARM devices '
          '(found: $arch). The BMONI signing library is arm64-only, so wallet '
          'creation cannot run on this device. Use a 64-bit Android device, or '
          'ask the developer for a 32-bit build of the BMONI signer library.',
        );
      }

      // 1. Create (or recover) the BMONI user
      final bmoniUserId = await _createOrRecoverBmoniUser(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
      );

      // 2. Set Wallet PIN and Provision Wallet on-device
      if (!await BmoniEmbeddedSdk.hasPin()) {
        await BmoniEmbeddedSdk.setPin(pin);
      }
      await CrashLog.write('onboarding: pin set');

      // Distinguish the Dart-side reads from the first NATIVE call
      // (initWallet loads libBMONISignerJNI.so and touches the Keystore).
      // If the process dies after this line with "found: false", the crash
      // is inside the native signer, not in secure storage.
      final hasLocalWallet = await BmoniEmbeddedSdk.hasWallet();
      await CrashLog.write('onboarding: provisioning wallet (local wallet found: $hasLocalWallet)');

      String userOwnerAddress;
      if (hasLocalWallet) {
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
      // The live sandbox returns the signable text under `message` — the
      // canonical integration example signs `challenge.message`. (`eip191Message`
      // was an earlier assumed field name that the API never returned.)
      final rawChallengeMessage =
          challenge['eip191Message'] ?? challenge['message'];
      final eip191Message =
          rawChallengeMessage is String ? rawChallengeMessage : null;
      if (eip191Message == null || eip191Message.isEmpty) {
        throw Exception(
          'BMONI did not return an EIP-191 challenge message: $challenge',
        );
      }
      final signature = await BmoniEmbeddedSdk.signMessage(eip191Message, pin: pin);
      await CrashLog.write('onboarding: owner-proof challenge signed');

      // A previous attempt may have already registered this wallet — recover
      // its ID instead of failing the whole onboarding again.
      Map<String, dynamic> walletResult;
      try {
        walletResult = await BmoniApi.createManagedWallet(
          userId: bmoniUserId,
          userOwnerAddress: userOwnerAddress,
          challengeId: challenge['challengeId'],
          signature: signature,
        );
      } catch (e) {
        if (!_isDuplicateError(e)) rethrow;
        final existingWalletId = await _recoverWalletId(bmoniUserId);
        if (existingWalletId == null) rethrow;
        walletResult = {'id': existingWalletId};
      }
      final smartWalletId = walletResult['id'];
      await CrashLog.write('onboarding: smart wallet registered ($smartWalletId)');

      // 4. Save Business mapping to Supabase (idempotent: a lost response on
      //    a previous attempt must not block the retry).
      final userId = _supabase.auth.currentUser!.id;
      String savedBmoniUserId = bmoniUserId;
      String savedWalletId = smartWalletId;
      try {
        await _supabase.from('business').insert({
          'owner_id': userId,
          'owner_bmoni_user_id': bmoniUserId,
          'owner_wallet_id': smartWalletId,
          'name': businessName,
        });
      } catch (e) {
        if (!_isDuplicateError(e)) rethrow;
        final existing = await _supabase
            .from('business')
            .select('owner_wallet_id, owner_bmoni_user_id')
            .eq('owner_id', userId)
            .maybeSingle();
        if (existing == null) rethrow;
        final existingWallet = existing['owner_wallet_id'];
        if (existingWallet == null ||
            existingWallet == 'PENDING_DEVICE_PROVISIONING') {
          // Placeholder row (e.g. from the prewarm script): fill in the real
          // wallet details instead of treating it as already done.
          await _supabase.from('business').update({
            'owner_bmoni_user_id': bmoniUserId,
            'owner_wallet_id': smartWalletId,
            'name': businessName,
          }).eq('owner_id', userId);
          await CrashLog.write('onboarding: upgraded placeholder business row');
        } else {
          savedBmoniUserId = existing['owner_bmoni_user_id'] ?? bmoniUserId;
          savedWalletId = existingWallet;
          await CrashLog.write('onboarding: business row already existed, continuing');
        }
      }
      await CrashLog.write('onboarding: business row saved');

      return {
        'bmoniUserId': savedBmoniUserId,
        'smartWalletId': savedWalletId,
        'userOwnerAddress': userOwnerAddress,
      };
    } catch (e) {
      await CrashLog.write('onboarding: FAILED -> $e');
      if (_isDuplicateError(e)) {
        throw Exception(
          'This email or phone is already registered on another account. '
          'Use a different email and phone to create a new account, or log in '
          'if you already completed setup.',
        );
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

      // Start Nigeria Onboarding (Auto-verifies BVN and provisions NGN rail).
      // If a previous attempt already kicked it off, treat that as success —
      // the dashboard's status poll handles the wait.
      try {
        await BmoniApi.startNigeriaOnboarding(
          userId: bmoniUserId,
          bvn: bvn,
          ngnWalletAddress: userOwnerAddress,
          ngnWalletIndex: 0,
        );
      } catch (e) {
        if (!_isDuplicateError(e)) rethrow;
        await CrashLog.write('kyc: rail activation already in progress, continuing');
      }
      await CrashLog.write('kyc: rail activation submitted');
    } catch (e) {
      await CrashLog.write('kyc: FAILED -> $e');
      throw Exception('KYC Activation failed: $e');
    }
  }
}