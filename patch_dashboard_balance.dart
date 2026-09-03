import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();

  // 1. Add _walletBalance variable
  var oldVars = '''
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProvisioning = false;
''';

  var newVars = '''
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProvisioning = false;
  double _walletBalance = 0.0;
''';

  content = content.replaceFirst(oldVars, newVars);

  // 2. Add balance fetching inside _fetchData()
  var oldFetch = '''
        if (mounted) {
          setState(() {
            _business = businessRes;
            _staffList = staffRes;
            _isLoading = false;
          });
        }
''';

  var newFetch = '''
        double fetchedBalance = 0.0;
        try {
          final balances = await BmoniApi.getBalances(userId: ownerUserId);
          for (var b in balances) {
            if (b['currency'] == 'CNGN') {
              fetchedBalance = double.tryParse(b['availableBalance'].toString()) ?? 0.0;
            }
          }
        } catch (e) {
          print('Error fetching balances: \$e');
        }

        if (mounted) {
          setState(() {
            _business = businessRes;
            _staffList = staffRes;
            _walletBalance = fetchedBalance;
            _isLoading = false;
          });
        }
''';

  content = content.replaceFirst(oldFetch, newFetch);

  // 3. Replace the hardcoded balance
  var oldBalance = '''
      balance: 150000.0,
''';

  var newBalance = '''
      balance: _walletBalance,
''';

  content = content.replaceFirst(oldBalance, newBalance);

  file.writeAsStringSync(content);
}
