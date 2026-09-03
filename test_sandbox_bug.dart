import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/env.dart';

void main() async {
  final url = Uri.parse('${Env.bmoniBaseUrl}/users');
  final payload = {
    "firstName": "Ademola",
    "lastName": "Ajala",
    "email": "ademola2993k@gmail.co",
    "phoneNumber": "+2348012345889"
  };

  print('Sending payload: ${jsonEncode(payload)}');
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': Env.bmoniApiKey,
    },
    body: jsonEncode(payload),
  );

  print('Response status: ${response.statusCode}');
  print('Response body: ${response.body}');
}
