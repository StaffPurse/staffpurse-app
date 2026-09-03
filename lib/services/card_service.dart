import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import 'bmoni_api.dart';

class CardService {
  final _supabase = Supabase.instance.client;

  /// Adds a staff member and issues a virtual card for them.
  Future<void> addStaffAndIssueCard({
    required String businessId,
    required String ownerUserId,
    required String ownerWalletId,
    required String staffName,
    required String staffPhone,
    required String pin,
    required String nin, // Owner's NIN, required for first card issuance
  }) async {
    try {
      // 1. Create StaffMember in DB
      final staffResponse = await _supabase.from('staff_member').insert({
        'business_id': businessId,
        'name': staffName,
        'phone_number': staffPhone,
      }).select('id').single();
      final staffId = staffResponse['id'];

      // 2. Call BMONI to create the card
      final createResponse = await BmoniApi.createCard(
        userId: ownerUserId,
        smartWalletId: ownerWalletId,
        cardName: "$staffName's Card",
        nin: nin,
      );

      final proposalId = (createResponse['proposalId'] ?? createResponse['id']).toString();
      if (proposalId == 'null' || proposalId.isEmpty) {
        throw Exception('Could not extract proposal ID from response: $createResponse');
      }

      String signPayload;

      // Handle signPayloadPending flag
      if (createResponse['signPayloadPending'] == true) {
        // Poll for sign payload
        signPayload = await BmoniApi.pollSignPayload(
          userId: ownerUserId,
          proposalId: proposalId,
        );
      } else {
        signPayload = createResponse['signPayload'] as String;
      }

      // 3. Sign the proposal using the hardware wallet via the SDK
      final signature = await BmoniEmbeddedSdk.signTransactionHash(
        signPayload,
        pin: pin,
      );

      // 4. Submit the signature to finalize card creation
      final submitResponse = await BmoniApi.submitSignature(
        userId: ownerUserId,
        proposalId: proposalId,
        signature: signature,
      );

      final cardId = (submitResponse['cardId'] ?? submitResponse['id']).toString();
      if (cardId == 'null' || cardId.isEmpty) {
         throw Exception('Could not extract card ID from response: $submitResponse');
      }
      
      // 5. Store CardAssignment in DB
      await _supabase.from('card_assignment').insert({
        'staff_member_id': staffId,
        'bmoni_card_id': cardId,
      });

    } catch (e) {
      throw Exception('Failed to issue card: $e');
    }
  }

  /// Sets spending limits for a specific card, checking provider caps first.
  Future<void> setCardLimits({
    required String ownerUserId,
    required String cardAssignmentId,
    required String bmoniCardId,
    required double dailyLimit,
    required double transactionLimit,
  }) async {
    try {
      // 1. Get the provider limits to validate
      final limitsResponse = await BmoniApi.getCardLimits(
        userId: ownerUserId,
        cardId: bmoniCardId,
      );

      // Ensure that BMONI's endpoints return numeric values we can check against.
      final maxTotalDailyLimit = (limitsResponse['maxTotalDailyLimit'] as num?)?.toDouble() ?? double.infinity;
      final maxSingleTransactionAmountCap = (limitsResponse['maxSingleTransactionLimitCap'] as num?)?.toDouble() ?? double.infinity;

      if (dailyLimit > maxTotalDailyLimit) {
        throw Exception("Daily limit ($dailyLimit) exceeds provider cap of $maxTotalDailyLimit.");
      }
      if (transactionLimit > maxSingleTransactionAmountCap) {
        throw Exception("Transaction limit ($transactionLimit) exceeds provider cap of $maxSingleTransactionAmountCap.");
      }

      // 2. Call BMONI to set limits
      await BmoniApi.setCardLimits(
        userId: ownerUserId,
        cardId: bmoniCardId,
        dailyLimit: dailyLimit,
        transactionLimit: transactionLimit,
      );

      // 3. Update our DB cache. Normalizing to minor units (kobo).
      await _supabase.from('card_assignment').update({
        'daily_limit_ngn': (dailyLimit * 100).toInt(),
        'per_transaction_limit_ngn': (transactionLimit * 100).toInt(),
      }).eq('id', cardAssignmentId);
      
    } catch (e) {
      throw Exception('Failed to set limits: $e');
    }
  }

  /// Freezes or unfreezes a card.
  /// Checks live BMONI status first to prevent blind retries on invalid states.
  Future<void> toggleCardFreeze({
    required String ownerUserId,
    required String cardAssignmentId,
    required String bmoniCardId,
    required bool freeze,
  }) async {
    final desiredStatus = freeze ? 'BLOCKED' : 'ACTIVE';

    try {
      // 1. Read live status before writing
      final cardInfo = await BmoniApi.getCard(
        userId: ownerUserId,
        cardId: bmoniCardId,
      );
      
      final currentStatus = (cardInfo['status'] as String?)?.toUpperCase() ?? 'UNKNOWN';

      if (currentStatus == desiredStatus) {
        // Already in desired state
        return;
      }

      // If card is permanently deactivated, lost, stolen, or otherwise un-blockable
      if (currentStatus != 'ACTIVE' && currentStatus != 'BLOCKED' && currentStatus != 'PENDING') {
        throw Exception('Cannot change status to $desiredStatus. Card is currently $currentStatus.');
      }

      // 2. Perform status transition
      await BmoniApi.updateCardStatus(
        userId: ownerUserId,
        cardId: bmoniCardId,
        status: desiredStatus,
      );

      // 3. Update DB cache
      await _supabase.from('card_assignment').update({
        'status': freeze ? 'frozen' : 'active',
      }).eq('id', cardAssignmentId);

    } catch (e) {
      throw Exception('Failed to toggle freeze: $e');
    }
  }

  /// Fetches card transactions from BMONI and caches them into Supabase.
  /// Normalizes major-unit numbers (e.g. 25.50) into minor units (kobo).
  Future<void> syncTransactions({
    required String ownerUserId,
    required String cardAssignmentId,
    required String bmoniCardId,
  }) async {
    try {
      final transactions = await BmoniApi.getCardTransactions(
        userId: ownerUserId,
        cardId: bmoniCardId,
      );

      for (final tx in transactions) {
        // Transactions endpoint returns major units (e.g. 25.50 for NGN)
        // We must normalize to minor units (kobo) for the TransactionCache
        final majorAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final koboAmount = (majorAmount * 100).toInt();

        final bmoniTxId = tx['id'] ?? tx['transactionId'];
        final description = tx['merchant'] ?? tx['description'] ?? 'Card Spend';
        final occurredAt = tx['createdAt'] ?? tx['date'] ?? DateTime.now().toIso8601String();

        // Upsert into Supabase cache
        await _supabase.from('transaction_cache').upsert({
          'card_assignment_id': cardAssignmentId,
          'bmoni_transaction_id': bmoniTxId,
          'amount_ngn': koboAmount,
          'description': description,
          'occurred_at': occurredAt,
          'synced_at': DateTime.now().toIso8601String(),
        }, onConflict: 'bmoni_transaction_id');
      }
    } catch (e) {
      throw Exception('Failed to sync transactions: $e');
    }
  }
}


