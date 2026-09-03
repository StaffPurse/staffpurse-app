import 'dart:io';

void main() {
  var file = File('lib/screens/kyc_screen.dart');
  var content = file.readAsStringSync();
  
  var oldAppBar = "appBar: AppBar(title: const Text('Activate Account')),";
  var newAppBar = '''
      appBar: AppBar(
        title: const Text('Activate Account'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
''';
  
  content = content.replaceFirst(oldAppBar, newAppBar);
  
  if (!content.contains("import 'package:supabase_flutter/supabase_flutter.dart';")) {
    content = "import 'package:supabase_flutter/supabase_flutter.dart';\n" + content;
  }
  if (!content.contains("import 'landing_screen.dart';")) {
    content = "import 'landing_screen.dart';\n" + content;
  }
  
  file.writeAsStringSync(content);
}
