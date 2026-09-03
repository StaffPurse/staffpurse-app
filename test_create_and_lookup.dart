import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:staffpurse_app/env.dart';

void main() async {
  // 1. Create a temporary user
  final createUrl = Uri.parse('\${Env.bmoniBaseUrl}/users');
  final createRes = await http.post(createUrl, headers: {
    "Content-Type": "application/json",
    "x-api-key": Env.bmoniApiKey,
  }, body: jsonEncode({
    "firstName": "Temp",
    "lastName": "User",
    "email": "temp\${DateTime.now().millisecondsSinceEpoch}@example.com",
    "phoneNumber": "+2348000000000"
  }));
  final userId = jsonDecode(createRes.body)['id'];
  print('Created User: \$userId');

  // 2. Lookup BVN
  final bvnUrl = Uri.parse('\${Env.bmoniBaseUrl}/users/\$userId/kyc/bvn-lookup/22222222222');
  final bvnRes = await http.get(bvnUrl, headers: {
    "Content-Type": "application/json",
    "x-api-key": Env.bmoniApiKey,
  });
  print('Lookup Status: \${bvnRes.statusCode}');
  print('Lookup Body: \${bvnRes.body}');
}
