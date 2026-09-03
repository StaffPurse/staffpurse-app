import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    'static Future<String> createUserAndKyc({',
    'static Future<String> createUserOnly({\n' +
    '    required String firstName,\n' +
    '    required String lastName,\n' +
    '    required String email,\n' +
    '    required String phoneNumber,\n' +
    '  }) async {\n' +
    '    final url = Uri.parse(\'\${Env.bmoniBaseUrl}/users\');\n' +
    '    \n' +
    '    final createUserPayload = {\n' +
    '      "firstName": firstName,\n' +
    '      "lastName": lastName,\n' +
    '      "email": email,\n' +
    '      "phoneNumber": phoneNumber,\n' +
    '    };\n' +
    '\n' +
    '    final userResponse = await http.post(\n' +
    '      url,\n' +
    '      headers: _headers,\n' +
    '      body: jsonEncode(createUserPayload),\n' +
    '    );\n' +
    '\n' +
    '    if (userResponse.statusCode < 200 || userResponse.statusCode >= 300) {\n' +
    '      throw Exception(\'Failed to create BMONI user: \${userResponse.body}\');\n' +
    '    }\n' +
    '\n' +
    '    final userData = _unwrapData(jsonDecode(userResponse.body));\n' +
    '    final userId = (userData[\'bmoniUserId\'] ?? userData[\'userId\'] ?? userData[\'id\']).toString();\n' +
    '    if (userId == \'null\' || userId.isEmpty) {\n' +
    '      throw Exception(\'Could not extract user ID from response: \$userData\');\n' +
    '    }\n' +
    '    return userId;\n' +
    '  }\n' +
    '\n' +
    '  static Future<void> activateKycOnly({\n' +
    '    required String userId,'
  );
  
  // Replace the return userId at the end of activateKycOnly (originally createUserAndKyc)
  content = content.replaceAll(
    'return userId;\n  }\n\n  /// Create a card',
    '}\n\n  /// Create a card'
  );
  
  file.writeAsStringSync(content);
}
