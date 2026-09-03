import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  var oldLogic = '''
  static Future<void> startNigeriaOnboarding({
    required String userId,
    required String bvn,
    required String ngnWalletAddress,
    required int ngnWalletIndex,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/onboarding/start-nigeria');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        "bvn": bvn,
        "ngnWalletAddress": ngnWalletAddress,
        "ngnWalletIndex": ngnWalletIndex,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to start Nigeria onboarding: \${response.body}');
    }
  }
''';

  var newLogic = '''
  static Future<Map<String, dynamic>> startNigeriaOnboarding({
    required String userId,
    required String bvn,
    required String ngnWalletAddress,
    required int ngnWalletIndex,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/onboarding/start-nigeria');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        "bvn": bvn,
        "ngnWalletAddress": ngnWalletAddress,
        "ngnWalletIndex": ngnWalletIndex,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to start Nigeria onboarding: \${response.body}');
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getOnboardingStatus({
    required String userId,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/onboarding/status');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to get onboarding status: \${response.body}');
    }
    return jsonDecode(response.body);
  }
''';

  content = content.replaceAll(oldLogic.trim(), newLogic.trim());
  file.writeAsStringSync(content);
}
