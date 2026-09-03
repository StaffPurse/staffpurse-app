import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  var oldFab = '''
      floatingActionButton: _isProvisioning
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IssueCardScreen()),
                );
              },
              label: const Text('Issue Card'),
              icon: const Icon(Icons.add_card),
            ),
''';

  // I'll change the FAB to a row or just add a button in the UI. 
  // Actually, adding a button in the AppBar is cleaner.
  var oldAppBar = '''
      appBar: AppBar(
        title: const Text('StaffPurse Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                );
              }
            },
          )
        ],
      ),
''';

  var newAppBar = '''
      appBar: AppBar(
        title: const Text('StaffPurse Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Fund Wallet',
            onPressed: _isProvisioning ? null : () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FundWalletScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                );
              }
            },
          )
        ],
      ),
''';

  content = content.replaceFirst(oldAppBar, newAppBar);
  
  if (!content.contains("import 'fund_wallet_screen.dart';")) {
    content = "import 'fund_wallet_screen.dart';\n" + content;
  }
  
  file.writeAsStringSync(content);
}
