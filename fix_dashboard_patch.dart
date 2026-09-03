import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Remove the invalid staffId from syncTransactions
  content = content.replaceFirst(
    "bmoniCardId: card['bmoni_card_id'],\n                            staffId: staff['id'],",
    "bmoniCardId: card['bmoni_card_id'],"
  );

  // 2. Add it to CardManagementScreen
  var oldPush = '''
                          builder: (_) => CardManagementScreen(
                            ownerUserId: _business!['owner_bmoni_user_id'],
                            bmoniCardId: card['bmoni_card_id'],
                            cardAssignmentId: card['id'],
''';
  var newPush = '''
                          builder: (_) => CardManagementScreen(
                            ownerUserId: _business!['owner_bmoni_user_id'],
                            bmoniCardId: card['bmoni_card_id'],
                            staffId: staff['id'],
                            cardAssignmentId: card['id'],
''';

  content = content.replaceFirst(oldPush, newPush);
  
  // 3. Fix the weird "// 3a. ORPHAN RECONCILIATION\n:" that my patch broke
  content = content.replaceAll(
    "// 3a. ORPHAN RECONCILIATION\n: Sync any rogue cards from BMONI directly",
    "// 3a. ORPHAN RECONCILIATION: Sync any rogue cards from BMONI directly"
  );
  
  file.writeAsStringSync(content);
}
