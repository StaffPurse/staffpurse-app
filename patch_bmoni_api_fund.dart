import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  var newMethod = '''
  static Future<Map<String, dynamic>> getDepositAccount({
    required String userId,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/bank-accounts/deposit-accounts/NGN');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch deposit account: \${response.body}');
    }
  }
''';

  // insert before the last brace
  var lastBraceIndex = content.lastIndexOf('}');
  content = content.substring(0, lastBraceIndex) + newMethod + '\n}\n';
  
  file.writeAsStringSync(content);
}
