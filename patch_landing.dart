import 'dart:io';

void main() {
  var file = File('lib/screens/landing_screen.dart');
  var content = file.readAsStringSync();
  
  // 1. Remove the white background
  content = content.replaceFirst("backgroundColor: Colors.white,", "");

  // 2. Replace the Title with RichText
  var oldTitle = '''
              const Text(
                'StaffPurse',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1420),
                ),
              ),
''';

  var newTitle = '''
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'StaffPurse',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: '.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurpleAccent,
                      ),
                    ),
                  ],
                ),
              ),
''';

  content = content.replaceFirst(oldTitle, newTitle);

  // 3. Update the subtitle color so it's readable on a dark background
  var oldSubtitle = '''
              const Text(
                'Issue capped virtual cards to your staff instantly, powered by BMONI.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF574F63),
                ),
              ),
''';

  var newSubtitle = '''
              const Text(
                'Issue capped virtual cards to your staff instantly, powered by BMONI.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
''';

  content = content.replaceFirst(oldSubtitle, newSubtitle);
  
  // 4. Also update the OutlinedButton text color to deepPurpleAccent for better contrast on dark
  var oldButtonText = '''
                  style: TextStyle(fontSize: 16, color: Color(0xFF7526C9), fontWeight: FontWeight.bold),
''';
  var newButtonText = '''
                  style: TextStyle(fontSize: 16, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
''';
  content = content.replaceFirst(oldButtonText, newButtonText);
  
  var oldBorder = '''
                  side: const BorderSide(color: Color(0xFF7526C9)),
''';
  var newBorder = '''
                  side: const BorderSide(color: Colors.deepPurpleAccent),
''';
  content = content.replaceFirst(oldBorder, newBorder);

  file.writeAsStringSync(content);
}
