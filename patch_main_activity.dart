import 'dart:io';

void main() {
  var file = File('android/app/src/main/kotlin/com/example/staffpurse_app/MainActivity.kt');
  var content = file.readAsStringSync();
  
  content = content.replaceFirst(
    "import io.flutter.embedding.android.FlutterActivity",
    "import io.flutter.embedding.android.FlutterFragmentActivity"
  );
  
  content = content.replaceFirst(
    "class MainActivity : FlutterActivity()",
    "class MainActivity : FlutterFragmentActivity()"
  );
  
  file.writeAsStringSync(content);
}
