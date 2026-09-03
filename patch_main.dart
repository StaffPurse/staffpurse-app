import 'dart:io';

void main() {
  var file = File('lib/main.dart');
  var content = file.readAsStringSync();
  
  // Replace the import
  content = content.replaceAll(
    "import 'screens/auth_screen.dart';", 
    "import 'screens/landing_screen.dart';"
  );
  
  // Replace the route
  content = content.replaceAll(
    "Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));",
    "Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingScreen()));"
  );
  
  file.writeAsStringSync(content);
}
