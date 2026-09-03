import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://embedded-dev.bmoni.com/v1';
  final headers = {
    'x-api-key': 'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4',
    'Content-Type': 'application/json',
  };

  final ts = DateTime.now().millisecondsSinceEpoch.toString();

  print('1. Creating User...');
  final createRes = await http.post(
    Uri.parse(baseUrl + '/users'),
    headers: headers,
    body: jsonEncode({
      "firstName": "Test" + ts,
      "lastName": "User" + ts,
      "email": "test" + ts + "@example.com",
      "phoneNumber": "+23480" + ts.substring(5)
    }),
  );
  
  final userData = jsonDecode(createRes.body);
  final userId = userData['user']?['bmoniUserId'] ?? userData['bmoniUserId'];
  print('User created: ' + userId.toString());

  // SKIP PATCH /kyc ENTIRELY
  // SKIP POST /activate ENTIRELY

  // TRY START NIGERIA DIRECTLY
  print('3. POST /onboarding/start-nigeria...');
  final startRes = await http.post(
    Uri.parse(baseUrl + '/users/' + userId.toString() + '/onboarding/start-nigeria'),
    headers: headers,
    body: jsonEncode({
      "bvn": "22222222222",
      "ngnWalletAddress": "0x1234567890123456789012345678901234567890",
      "ngnWalletIndex": 0
    }),
  );
  
  print('Start response: ' + startRes.statusCode.toString() + ' ' + startRes.body);
}
