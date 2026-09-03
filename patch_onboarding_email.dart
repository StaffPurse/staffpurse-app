import 'dart:io';

void main() {
  var file = File('lib/screens/onboarding_screen.dart');
  var content = file.readAsStringSync();
  
  var oldLogic = '''
  final _phoneCtrl = TextEditingController();
''';

  var newLogic = '''
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefill the email from Supabase Auth
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      _emailCtrl.text = user.email!;
    }
  }
''';

  content = content.replaceFirst(oldLogic, newLogic);
  
  // Need to import supabase if not already imported
  if (!content.contains("import 'package:supabase_flutter/supabase_flutter.dart';")) {
    content = "import 'package:supabase_flutter/supabase_flutter.dart';\n" + content;
  }
  
  file.writeAsStringSync(content);
}
