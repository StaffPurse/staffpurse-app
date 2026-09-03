import 'dart:io';

void main() {
  var file = File('lib/screens/kyc_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceFirst(
    "await storage.write(key: 'owner_nin', _ninCtrl.text.trim());",
    "await storage.write(key: 'owner_nin', value: _ninCtrl.text.trim());"
  );
  file.writeAsStringSync(content);
}
