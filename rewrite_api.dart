import 'dart:io';

void main() {
  var file = File('lib/services/bmoni_api.dart');
  var content = file.readAsStringSync();
  
  // Find where createUserOnly starts
  var startIdx = content.indexOf('static Future<String> createUserOnly({');
  // Find where createCard starts
  var endIdx = content.indexOf('/// Create a card');
  
  if (startIdx == -1 || endIdx == -1) {
    print("Could not find boundaries");
    return;
  }
  
  var newMethods = '''
  static Future<String> createUserOnly({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
  }) async {
    final url = Uri.parse('\${Env.bmoniBaseUrl}/users');
    
    final createUserPayload = {
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      "phoneNumber": phoneNumber,
    };

    final userResponse = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(createUserPayload),
    );

    if (userResponse.statusCode < 200 || userResponse.statusCode >= 300) {
      throw Exception('Failed to create BMONI user: \${userResponse.body}');
    }

    final userData = _unwrapData(jsonDecode(userResponse.body));
    final userId = (userData['bmoniUserId'] ?? userData['userId'] ?? userData['id']).toString();
    if (userId == 'null' || userId.isEmpty) {
      throw Exception('Could not extract user ID from response: \$userData');
    }
    return userId;
  }

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
  
  var newContent = content.substring(0, startIdx) + newMethods + content.substring(endIdx);
  file.writeAsStringSync(newContent);
}
