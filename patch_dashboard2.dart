import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
    "bmoniCardId: card['bmoni_card_id'],",
    "bmoniCardId: card['bmoni_card_id'],\n                            staffId: staff['id'],"
  );

  file.writeAsStringSync(content);
}
