import 'dart:convert';

void main() {
  var jsonString = '{"user": {"id": "123"}}';
  var decoded = jsonDecode(jsonString);
  print('decoded type: ${decoded.runtimeType}');
  
  if (decoded is Map<String, dynamic>) {
    print('is Map<String, dynamic>');
  } else {
    print('NOT Map<String, dynamic>');
  }
}
