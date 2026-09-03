import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  var oldMethod = '''
  static Future<Map<String, dynamic>> getOwnerProofChallenge({
    required String userOwnerAddress,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/smart-wallets/owner-proof-challenges');
    final response = await http.post(
      url,
      headers: _headers,
      body: '{"currency": "CNGN", "userOwnerAddress": "\$userOwnerAddress"}',
    );
''';

  var newMethod = '''
  static Future<Map<String, dynamic>> getOwnerProofChallenge({
    required String userId,
    required String userOwnerAddress,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/smart-wallets/owner-proof-challenges');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({"currency": "CNGN", "userOwnerAddress": userOwnerAddress}),
    );
''';

  content = content.replaceAll(oldMethod.trim(), newMethod.trim());
  file.writeAsStringSync(content);
}
