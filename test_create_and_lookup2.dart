import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://embedded-dev.bmoni.com/v1';
  final apiKey = 'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4';

  final createUrl = Uri.parse('$baseUrl/users');
  final createRes = await http.post(createUrl, headers: {
    "Content-Type": "application/json",
    "x-api-key": apiKey,
  }, body: jsonEncode({
    "firstName": "Temp",
    "lastName": "User",
    "email": "temp${DateTime.now().millisecondsSinceEpoch}@example.com",
    "phoneNumber": "+2348000000000"
  }));
  final userId = jsonDecode(createRes.body)['id'];
  print('Created User: $userId');

  final bvnUrl = Uri.parse('$baseUrl/users/$userId/kyc/bvn-lookup/22222222222');
  final bvnRes = await http.get(bvnUrl, headers: {
    "Content-Type": "application/json",
    "x-api-key": apiKey,
  });
  print('Lookup Status: ${bvnRes.statusCode}');
  print('Lookup Body: ${bvnRes.body}');
}
