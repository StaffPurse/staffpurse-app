import 'dart:io';

void main() {
  var file = File('lib/services/onboarding_service.dart');
  var content = file.readAsStringSync();
  
  var oldCatch = '''
    } catch (e) {
      throw Exception('Setup failed: \$e');
    }
''';

  var newCatch = '''
    } catch (e) {
      if (e.toString().contains('409') || e.toString().toLowerCase().contains('already exists')) {
        throw Exception('This phone or email is already registered with BMONI.\\n\\nIf you already have an account, please click the Log Out button in the top right, then Login with your existing credentials instead of creating a new one.');
      }
      throw Exception('Setup failed: \$e');
    }
''';

  content = content.replaceFirst(oldCatch, newCatch);
  file.writeAsStringSync(content);
}
