import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains("import '../services/bmoni_api.dart';")) {
    content = "import '../services/bmoni_api.dart';\n" + content;
    file.writeAsStringSync(content);
  }
}
