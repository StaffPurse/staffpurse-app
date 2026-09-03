import 'dart:convert';
import 'lib/services/bmoni_api.dart';

void main() {
  final payload = {
    "firstName": "Test",
    "lastName": "User",
    "email": "ademola2993k@gmail.co",
    "phoneNumber": "+2348012345889",
  };
  print('Payload being sent: ${jsonEncode(payload)}');
}
