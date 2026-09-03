import 'dart:io';

void main() {
  var file = File('lib/services/onboarding_service.dart');
  var content = file.readAsStringSync();
  
  var oldLogic = '''
      // 4. Start Nigeria Onboarding (Auto-verifies BVN and provisions NGN rail)
      await BmoniApi.startNigeriaOnboarding(
        userId: bmoniUserId,
        bvn: bvn,
        ngnWalletAddress: userOwnerAddress,
        ngnWalletIndex: 0,
      );

      // 5. Save Business mapping to Supabase
''';

  var newLogic = '''
      // 4. Start Nigeria Onboarding (Auto-verifies BVN and provisions NGN rail)
      final startRes = await BmoniApi.startNigeriaOnboarding(
        userId: bmoniUserId,
        bvn: bvn,
        ngnWalletAddress: userOwnerAddress,
        ngnWalletIndex: 0,
      );
      
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

      // 5. Save Business mapping to Supabase
''';

  content = content.replaceAll(oldLogic.trim(), newLogic.trim());
  file.writeAsStringSync(content);
}
