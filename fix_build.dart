import 'dart:io';

void main() {
  var file = File('lib/screens/onboarding_screen.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('BMoniTextField', 'BMoniTextFormField');
  file.writeAsStringSync(content);
}
