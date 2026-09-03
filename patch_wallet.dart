import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  var newMethods = '''
  static Future<Map<String, dynamic>> getOwnerProofChallenge({
    required String userOwnerAddress,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/smart-wallets/owner-proof-challenges');
    final response = await http.post(
      url,
      headers: _headers,
      body: '{"currency": "CNGN", "userOwnerAddress": "\$userOwnerAddress"}',
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(jsonDecode(response.body));
    }
    throw Exception('Failed to get challenge: \${response.body}');
  }

  static Future<Map<String, dynamic>> createManagedWallet({
    required String userId,
    required String userOwnerAddress,
    required String challengeId,
    required String signature,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/smart-wallets/create-managed');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        "currency": "CNGN",
        "userOwnerAddress": userOwnerAddress,
        "ownerProofChallengeId": challengeId,
        "ownerProofSignature": signature,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(jsonDecode(response.body));
    }
    throw Exception('Failed to create managed wallet: \${response.body}');
  }

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

  /// Create a card
''';

  content = content.replaceAll('/// Create a card', newMethods);
  file.writeAsStringSync(content);
}
