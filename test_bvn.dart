import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://embedded-dev.bmoni.com/v1/kyc/bvn-lookup/22222222222');
  final response = await http.get(url, headers: {
    "Content-Type": "application/json",
    "x-api-key": "pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4",
  });
  print('Status: \${response.statusCode}');
  print('Body: \${response.body}');
}
