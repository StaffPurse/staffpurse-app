import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
    "bool _isLoading = true;\n  bool _isProvisioning = false;",
    "bool _isLoading = true;\n  bool _isProvisioning = false;\n  double _walletBalance = 0.0;"
  );
  
  file.writeAsStringSync(content);
}
