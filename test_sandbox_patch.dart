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
  
  if (createRes.statusCode >= 300) {
    print('Failed to create user: ' + createRes.body);
    return;
  }
  
  final userData = jsonDecode(createRes.body);
  final userId = userData['user']?['bmoniUserId'];
  print('User data: ' + createRes.body);
  print('User created: ' + userId.toString());

  print('2. PATCH /kyc...');
  final patchRes = await http.patch(
    Uri.parse(baseUrl + '/users/' + userId.toString() + '/kyc'),
    headers: headers,
    body: jsonEncode({
      "dateOfBirth": "1990-01-01",
      "address": {
        "streetLine1": "1 Hackathon Way",
        "city": "Lagos",
        "state": "Lagos",
        "postalCode": "100001",
        "countryCode": "NGA"
      },
      "identificationNumbers": {
        "bvn": "22222222222"
      }
    }),
  );
  
  print('PATCH response: ' + patchRes.statusCode.toString() + ' ' + patchRes.body);
}
