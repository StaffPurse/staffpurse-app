import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

void main() async {
  final baseUrl = 'https://embedded-dev.bmoni.com/v1';
  final apiKey = 'pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4';
  final randomPhone = "+23480\${Random().nextInt(9000000) + 1000000}";

  final createUrl = Uri.parse('\$baseUrl/users');
  final createRes = await http.post(createUrl, headers: {
    "Content-Type": "application/json",
    "x-api-key": apiKey,
  }, body: jsonEncode({
    "firstName": "Temp",
    "lastName": "User",
    "email": "temp\${DateTime.now().millisecondsSinceEpoch}@example.com",
    "phoneNumber": randomPhone
  }));
  print(createRes.body);
}
