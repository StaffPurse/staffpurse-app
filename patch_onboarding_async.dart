import 'dart:io';

void main() {
  var file = File('lib/services/onboarding_service.dart');
  var content = file.readAsStringSync();
  
  var oldLogic = '''
      // Wait for the workflow to complete
      final workflowId = startRes['workflowId'];
      int retries = 0;
      bool isActive = false;
      while (retries < 10 && !isActive) {
        await Future.delayed(Duration(seconds: 2));
        final status = await BmoniApi.getOnboardingStatus(userId: bmoniUserId);
        if (status['status']?['hasLocalWallet'] == true) {
          isActive = true;
        }
        retries++;
      }
      
      if (!isActive) {
        throw Exception('Nigeria onboarding timed out waiting for wallet activation');
      }
''';

  content = content.replaceFirst(oldLogic, '');
  file.writeAsStringSync(content);
}
