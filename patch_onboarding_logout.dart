import 'dart:io';

void main() {
  var file = File('lib/screens/onboarding_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Add Log Out button to AppBar
  var oldAppBar = "appBar: AppBar(title: const Text('Setup Profile')),";
  var newAppBar = '''
      appBar: AppBar(
        title: const Text('Setup Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                // Return to AuthScreen/LandingScreen cleanly
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
  
  // 2. We need to import landing_screen.dart if it's not there
  if (!content.contains("import 'landing_screen.dart';")) {
    content = "import 'landing_screen.dart';\n" + content;
  }
  
  file.writeAsStringSync(content);
}
