import 'dart:io';

void main() {
  var file = File('lib/screens/onboarding_screen.dart');
  var content = file.readAsStringSync();
  
  var oldCall = '''
      // 1. Get Challenge
      final challenge = await BmoniApi.getOwnerProofChallenge(userOwnerAddress: userOwnerAddress);
''';

  var newCall = '''
      // 1. Get Challenge
      final challenge = await BmoniApi.getOwnerProofChallenge(
        userId: _bmoniUserId!,
        userOwnerAddress: userOwnerAddress,
      );
''';

  content = content.replaceAll(oldCall.trim(), newCall.trim());
  file.writeAsStringSync(content);
}
