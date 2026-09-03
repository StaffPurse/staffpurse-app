import 'dart:io';

void main() {
  var file = File('lib/services/card_service.dart');
  var content = file.readAsStringSync();
  
  var newMethod = '''
  /// Removes a staff member (Freezes the card and hides them from the dashboard)
  Future<void> removeStaff({
    required String ownerUserId,
    required String staffId,
    required String cardAssignmentId,
    required String bmoniCardId,
  }) async {
    try {
      // 1. Freeze the card on BMONI (per AGENTS.md rule: never deactivate, only freeze/block)
      final cardInfo = await BmoniApi.getCard(
        userId: ownerUserId,
        cardId: bmoniCardId,
      );
      
      final currentStatus = (cardInfo['status'] ?? cardInfo['cardStatus'] ?? cardInfo['state'] as String?)?.toUpperCase() ?? 'UNKNOWN';

      if (currentStatus != 'BLOCKED') {
        if (currentStatus != 'ACTIVE' && currentStatus != 'PENDING') {
          // It's already in an irreversible state, we can skip the API call
        } else {
          await BmoniApi.updateCardStatus(
            userId: ownerUserId,
            cardId: bmoniCardId,
            status: 'BLOCKED',
          );
        }
      }

      // 2. Mark staff member as removed in DB
      await _supabase.from('staff_member').update({
        'status': 'removed',
      }).eq('id', staffId);

      // 3. Mark card as revoked locally
      await _supabase.from('card_assignment').update({
        'status': 'revoked',
      }).eq('id', cardAssignmentId);

    } catch (e) {
      throw Exception('Failed to remove staff: \$e');
    }
  }
}
''';

  content = content.replaceFirst(RegExp(r'\}\s*$'), newMethod);
  file.writeAsStringSync(content);
}
