import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  var oldMethod = '''
  static Future<void> activateKycOnly({
    required String userId,
    required String dateOfBirth,
    required String bvn,
  }) async {
    final kycUrl = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/kyc/activate');
    final kycPayload = {
      "dateOfBirth": dateOfBirth,
      "address": {
        "streetLine1": "1 Hackathon Way",
        "city": "Lagos",
        "state": "Lagos",
        "postalCode": "100001",
        "countryCode": "NGA"
      },
      "identificationNumbers": {
        "bvn": bvn
      }
    };

    final kycResponse = await http.post(
      kycUrl,
      headers: _headers,
      body: jsonEncode(kycPayload),
    );

    if (kycResponse.statusCode < 200 || kycResponse.statusCode >= 300) {
      throw Exception('Failed to activate KYC: \${kycResponse.body}');
    }
  }
''';

  var newMethod = '''
  static Future<void> activateKycOnly({
    required String userId,
    required String dateOfBirth,
    required String bvn,
  }) async {
    // 1. PATCH the KYC profile
    final patchUrl = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/kyc');
    final kycPayload = {
      "dateOfBirth": dateOfBirth,
      "address": {
        "streetLine1": "1 Hackathon Way",
        "city": "Lagos",
        "state": "Lagos",
        "postalCode": "100001",
        "countryCode": "NGA"
      },
      "identificationNumbers": {
        "bvn": bvn
      }
    };

    final patchResponse = await http.patch(
      patchUrl,
      headers: _headers,
      body: jsonEncode(kycPayload),
    );

    if (patchResponse.statusCode < 200 || patchResponse.statusCode >= 300) {
      throw Exception('Failed to PATCH KYC: \${patchResponse.body}');
    }

    // 2. ACTIVATE KYC (Empty body for NGN)
    final activateUrl = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/kyc/activate');
    final activateResponse = await http.post(
      activateUrl,
      headers: _headers,
    );

    if (activateResponse.statusCode < 200 || activateResponse.statusCode >= 300) {
      throw Exception('Failed to activate KYC: \${activateResponse.body}');
    }
  }
''';

  content = content.replaceAll(oldMethod.trim(), newMethod.trim());
  file.writeAsStringSync(content);
}
