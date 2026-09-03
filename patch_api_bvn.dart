import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();

  var oldBvn = '''
  static Future<Map<String, dynamic>> bvnLookup({
    required String bvn,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/kyc/bvn-lookup/\$bvn');
''';

  var newBvn = '''
  static Future<Map<String, dynamic>> bvnLookup({
    required String userId,
    required String bvn,
  }) async {
    // The exact verified bvn-lookup endpoint requires the active userId!
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/kyc/bvn-lookup/\$bvn');
''';

  content = content.replaceFirst(oldBvn, newBvn);
  file.writeAsStringSync(content);
}
