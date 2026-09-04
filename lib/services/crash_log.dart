import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Returns the Dart VM's target CPU architecture as reported in
/// Platform.version, e.g. 'android_arm64', 'android_x64', 'android_arm'.
///
/// The BMONI signer native library (libBMONISignerJNI.so) ships only for
/// arm64-v8a, so on any other ABI the SDK throws an uncatchable
/// UnsatisfiedLinkError that kills the process. Knowing the arch in-app is
/// the cheapest way to diagnose that — no adb required.
String deviceArch() {
  final v = Platform.version;
  // Platform.version reports the target arch as `on 'android_arm64'` or
  // `on "android_arm"` — the quote style varies across Dart versions.
  final m = RegExp(r"on ['"]([^'"]+)['"]").firstMatch(v);
  return m != null ? m.group(1)! : v;
}

/// Minimal on-device diagnostics log.
///
/// Writes a timestamped trace of onboarding steps and any Dart-level errors
/// to a file in the app's documents directory so a crash can be diagnosed
/// from the APK alone (no IDE / logcat attached). Native process crashes
/// (SIGSEGV etc.) cannot be captured from Dart — those still need `adb
/// logcat` — but every step of the BMONI onboarding flow is traced here, so
/// you can always see how far the flow got.
class CrashLog {
  CrashLog._();

  static const int _maxLines = 200;
  static File? _file;

  static Future<File> _logFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/staffpurse_crash.log');
    _file = file;
    return file;
  }

  /// Appends a line to the crash log. Never throws — logging must not
  /// interfere with the flow being diagnosed.
  static Future<void> write(String message) async {
    try {
      final file = await _logFile();
      await file.writeAsString(
        '${DateTime.now().toIso8601String()} $message\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Intentionally swallowed: diagnostics must never break the app.
    }
  }

  /// Returns the last [_maxLines] lines of the log, or `null` if none yet.
  static Future<String?> readLast() async {
    try {
      final file = await _logFile();
      if (!await file.exists()) return null;
      final lines = await file.readAsLines();
      final tail = lines.length > _maxLines
          ? lines.sublist(lines.length - _maxLines)
          : lines;
      return tail.join('\n');
    } catch (_) {
      return null;
    }
  }

  /// Wipes the log (e.g. after the user copies it out).
  static Future<void> clear() async {
    try {
      final file = await _logFile();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Intentionally swallowed.
    }
  }
}