import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'bmoni_api.dart';
import 'crash_log.dart';

/// Tears down the current user's account everywhere we can reach.
///
/// BMONI deletion deactivates (reversible 90 days) and requires empty
/// wallets, so a funded wallet fails there — that failure is reported back
/// as a warning while the rest of the cleanup still completes. The Supabase
/// auth user itself cannot be removed client-side (gotrue 2.2.0 only exposes
/// the admin delete), so the email stays bound to the login; signing back in
/// lands on a clean onboarding, and the recovery logic in OnboardingService
/// adopts + reactivates the old BMONI user.
class AccountService {
  final _supabase = Supabase.instance.client;
  static const _storage = FlutterSecureStorage();

  static const _localKeys = [
    'owner_nin',
    'owner_bmoni_user_id',
    'owner_bmoni_email',
    'owner_bmoni_phone',
    'owner_supabase_uid',
  ];

  /// Deletes the account and signs out. Returns a warning string if the BMONI
  /// side could not be deleted (e.g. the wallet still holds funds), else null.
  Future<String?> deleteAccount() async {
    final supabaseUid = _supabase.auth.currentUser?.id;
    final bmoniUserId = await _storage.read(key: 'owner_bmoni_user_id');
    String? warning;

    // 1. BMONI user (best effort — fails loudly if wallets hold funds).
    if (bmoniUserId != null && bmoniUserId.isNotEmpty) {
      try {
        await BmoniApi.deleteUser(userId: bmoniUserId);
        await CrashLog.write('account: BMONI user deleted ($bmoniUserId)');
      } catch (e) {
        await CrashLog.write('account: BMONI delete failed: $e');
        warning =
            'Your BMONI account could not be deleted (wallets must be empty). '
            'Everything else has been removed.';
      }
    }

    // 2. Supabase business data (staff, cards, transactions cascade).
    if (supabaseUid != null) {
      try {
        await _supabase.from('business').delete().eq('owner_id', supabaseUid);
        await CrashLog.write('account: supabase business data deleted');
      } catch (e) {
        await CrashLog.write('account: supabase delete failed: $e');
      }
    }

    // 3. On-device wallet + PIN gate.
    try {
      BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: false);
      try {
        await BmoniEmbeddedSdk.deleteWallet();
      } finally {
        BmoniEmbeddedSdk.initialize(pinLength: 6, requirePin: true);
      }
      await CrashLog.write('account: local wallet deleted');
    } catch (e) {
      await CrashLog.write('account: local wallet delete failed: $e');
    }

    // 4. Local secure storage.
    for (final key in _localKeys) {
      await _storage.delete(key: key);
    }

    // 5. Sign out.
    await _supabase.auth.signOut();
    await CrashLog.write('account: deletion complete, signed out');
    return warning;
  }
}