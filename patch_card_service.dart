import 'dart:io';

void main() {
  var file = File('lib/services/card_service.dart');
  var content = file.readAsStringSync();
  
  var oldLogic = '''
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
        cardName: "\$staffName's Card",
        nin: nin,
      );

      final proposalId = (createResponse['proposalId'] ?? createResponse['id']).toString();
''';

  var newLogic = '''
    try {
      // 1. Create StaffMember in DB
      final staffResponse = await _supabase.from('staff_member').insert({
        'business_id': businessId,
        'name': staffName,
        'phone_number': staffPhone,
      }).select('id').single();
      final staffId = staffResponse['id'];

      // 2. Call BMONI to create the card
      Map<String, dynamic> createResponse;
      try {
        createResponse = await BmoniApi.createCard(
          userId: ownerUserId,
          smartWalletId: ownerWalletId,
          cardName: "\$staffName's Card",
          nin: nin,
        );
      } catch (e) {
        // Rollback DB if BMONI API fails (e.g. 404 Wallet Not Found)
        await _supabase.from('staff_member').delete().eq('id', staffId);
        rethrow;
      }

      final proposalId = (createResponse['proposalId'] ?? createResponse['id']).toString();
''';

  content = content.replaceAll(oldLogic.trim(), newLogic.trim());
  file.writeAsStringSync(content);
}
