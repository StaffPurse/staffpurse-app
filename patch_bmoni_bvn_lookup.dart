import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  var newMethod = '''
  static Future<Map<String, dynamic>> bvnLookup({
    required String bvn,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/kyc/bvn-lookup/\$bvn');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('BVN lookup failed: \${response.body}');
    }
    return jsonDecode(response.body);
  }
''';

  content = content.replaceFirst('class BmoniApi {', 'class BmoniApi {\n' + newMethod);
  file.writeAsStringSync(content);
}
