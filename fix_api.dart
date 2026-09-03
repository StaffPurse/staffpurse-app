import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    'static Future<void> activateKycOnly({\n' +
    '    required String userId,\n' +
    '    required String firstName,\n' +
    '    required String lastName,\n' +
    '    required String email,\n' +
    '    required String phoneNumber,\n' +
    '    required String dateOfBirth,\n' +
    '    required String bvn,\n' +
    '  })',
    'static Future<void> activateKycOnly({\n' +
    '    required String userId,\n' +
    '    required String dateOfBirth,\n' +
    '    required String bvn,\n' +
    '  })'
  );
  
  file.writeAsStringSync(content);
}
