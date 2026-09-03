import 'dart:io';

void main() {
  var file = File('lib/screens/onboarding_screen.dart');
  var content = file.readAsStringSync();
  
  var oldLogic = '''
    try {
      final res = await BmoniApi.bvnLookup(bvn: bvn);
      if (mounted) {
        setState(() {
          final firstName = res['firstName'] ?? '';
          final lastName = res['lastName'] ?? '';
          _bvnVerifiedName = "\$firstName \$lastName".trim();
          if (_bvnVerifiedName!.isEmpty) _bvnVerifiedName = "Verified";
        });
      }
    } catch (e) {
''';

  var newLogic = '''
    try {
      if (bvn == '22222222222') {
        // Sandbox bypass: Mock the verified name instantly
        await Future.delayed(const Duration(milliseconds: 600)); // simulate network
        if (mounted) {
          setState(() {
            _bvnVerifiedName = "John Doe (Sandbox)";
          });
        }
      } else {
        final res = await BmoniApi.bvnLookup(bvn: bvn);
        if (mounted) {
          setState(() {
            final firstName = res['firstName'] ?? '';
            final lastName = res['lastName'] ?? '';
            _bvnVerifiedName = "\$firstName \$lastName".trim();
            if (_bvnVerifiedName!.isEmpty) _bvnVerifiedName = "Verified";
          });
        }
      }
    } catch (e) {
''';

  content = content.replaceFirst(oldLogic, newLogic);
  file.writeAsStringSync(content);
}
