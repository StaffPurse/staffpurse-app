import 'dart:io';

void main() {
  var file = File('lib/screens/dashboard_screen.dart');
  var content = file.readAsStringSync();
  
  var oldState = '''
        if (mounted) {
          setState(() {
            _business = businessRes;
            _staffCards = staffRes;
            _transactions = mappedTxs;
          });
        }
''';

  var newState = '''
        double fetchedBalance = 0.0;
        try {
          final balances = await BmoniApi.getBalances(userId: ownerUserId);
          for (var b in balances) {
            if (b['currency'] == 'CNGN') {
              fetchedBalance = double.tryParse(b['availableBalance']?.toString() ?? b['balance']?.toString() ?? b['amount']?.toString() ?? '0') ?? 0.0;
            }
          }
        } catch (e) {
          print('Error fetching balances: \$e');
        }

        if (mounted) {
          setState(() {
            _business = businessRes;
            _staffCards = staffRes;
            _transactions = mappedTxs;
            _walletBalance = fetchedBalance;
          });
        }
''';

  content = content.replaceFirst(oldState, newState);
  
  // also add _isLoading = false in the finally block if it wasn't there
  
  file.writeAsStringSync(content);
}
