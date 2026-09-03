import 'dart:io';

void main() {
  var file = File('android/app/build.gradle.kts');
  var content = file.readAsStringSync();
  
  if (!content.contains("dependencies {")) {
    content += '\ndependencies {\n    implementation("androidx.appcompat:appcompat:1.6.1")\n}\n';
  } else {
    content = content.replaceFirst("dependencies {", "dependencies {\n    implementation(\"androidx.appcompat:appcompat:1.6.1\")");
  }
  
  file.writeAsStringSync(content);
}
