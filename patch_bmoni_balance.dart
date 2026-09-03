import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  var newMethod = '''
  static Future<List<dynamic>> getBalances({
    required String userId,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/smart-wallets/account/balances');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return decoded['data'] ?? [];
    } else {
      throw Exception('Failed to fetch balances: \${response.body}');
    }
  }
''';

  var lastBraceIndex = content.lastIndexOf('}');
  content = content.substring(0, lastBraceIndex) + newMethod + '\n}\n';
  
  file.writeAsStringSync(content);
}
