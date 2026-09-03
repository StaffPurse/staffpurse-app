import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
    "fetchedBalance = double.tryParse(b['availableBalance'].toString()) ?? 0.0;",
    "fetchedBalance = double.tryParse(b['availableBalance']?.toString() ?? b['balance']?.toString() ?? b['amount']?.toString() ?? '0') ?? 0.0;"
  );
  
  file.writeAsStringSync(content);
}
