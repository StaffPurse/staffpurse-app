import 'dart:io';

void main() {
  var file = File('android/app/src/main/kotlin/com/example/staffpurse_app/MainActivity.kt');
  var content = file.readAsStringSync();
  
  var newImports = '''
import android.os.Bundle
import android.content.Context
import java.security.KeyStore
import java.io.File
''';

  var onCreateMethod = '''
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
        val isFirstRun = prefs.getBoolean("is_first_run_after_install", true)
        
        if (isFirstRun) {
            try {
                // Clear the Keystore aliases used by FlutterSecureStorage and BMONI to prevent EncryptedSharedPreferences crash on reinstall
                val keyStore = KeyStore.getInstance("AndroidKeyStore")
                keyStore.load(null)
                
                // flutter_secure_storage default master key
                if (keyStore.containsAlias("_androidx_security_master_key_")) {
                    keyStore.deleteEntry("_androidx_security_master_key_")
                }
                
                // BMONISigner wallet key
                if (keyStore.containsAlias("bmoni_wallet_key")) {
                    keyStore.deleteEntry("bmoni_wallet_key")
                }
                
                // Clear all shared preferences XML files except app_prefs
                val sharedPrefsDir = File(applicationInfo.dataDir, "shared_prefs")
                if (sharedPrefsDir.exists() && sharedPrefsDir.isDirectory) {
                    sharedPrefsDir.listFiles()?.forEach { file ->
                        if (file.name != "app_prefs.xml") {
                            file.delete()
                        }
                    }
                }
                
                prefs.edit().putBoolean("is_first_run_after_install", false).apply()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
''';

  if (!content.contains("import android.os.Bundle")) {
    content = content.replaceFirst("import io.flutter.embedding.android.FlutterFragmentActivity", "import io.flutter.embedding.android.FlutterFragmentActivity\n" + newImports);
  }
  
  if (!content.contains("override fun onCreate")) {
    content = content.replaceFirst("class MainActivity : FlutterFragmentActivity()", "class MainActivity : FlutterFragmentActivity() {\n" + onCreateMethod + "\n}");
  }
  
  file.writeAsStringSync(content);
}
