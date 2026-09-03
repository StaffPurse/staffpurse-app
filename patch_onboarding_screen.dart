import 'dart:io';

void main() {
  var file = File('lib/screens/onboarding_screen.dart');
  var content = file.readAsStringSync();
  
  var oldMethod = '''
  Future<void> _step3SetupWallet() async {
    if (_bmoniUserId == null) return;
    setState(() { _isLoading = true; _statusMessage = "Step 3: Setting up Smart Wallet..."; });
    try {
      if (!await BmoniEmbeddedSdk.hasPin()) {
        await BmoniEmbeddedSdk.setPin(_pinCtrl.text);
      }
      String walletAddress;
      if (await BmoniEmbeddedSdk.hasWallet()) {
        walletAddress = (await BmoniEmbeddedSdk.walletAddress())!;
      } else {
        walletAddress = await BmoniEmbeddedSdk.initWallet();
      }
      
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('business').insert({
        'owner_id': userId,
        'owner_bmoni_user_id': _bmoniUserId,
        'owner_wallet_id': walletAddress,
        'name': _businessNameCtrl.text,
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() => _statusMessage = "Error in Step 3: \$e");
    } finally {
      setState(() => _isLoading = false);
    }
  }
''';

  var newMethod = '''
  Future<void> _step3SetupWallet() async {
    if (_bmoniUserId == null) return;
    setState(() { _isLoading = true; _statusMessage = "Step 3: Setting up Smart Wallet..."; });
    try {
      if (!await BmoniEmbeddedSdk.hasPin()) {
        await BmoniEmbeddedSdk.setPin(_pinCtrl.text);
      }
      String userOwnerAddress;
      if (await BmoniEmbeddedSdk.hasWallet()) {
        userOwnerAddress = (await BmoniEmbeddedSdk.walletAddress())!;
      } else {
        userOwnerAddress = await BmoniEmbeddedSdk.initWallet();
      }

      // 1. Get Challenge
      final challenge = await BmoniApi.getOwnerProofChallenge(userOwnerAddress: userOwnerAddress);
      
      // 2. Sign Challenge
      final signature = await BmoniEmbeddedSdk.signMessage(challenge['eip191Message'], pin: _pinCtrl.text);
      
      // 3. Create Managed Wallet
      final walletResult = await BmoniApi.createManagedWallet(
        userId: _bmoniUserId!,
        userOwnerAddress: userOwnerAddress,
        challengeId: challenge['challengeId'],
        signature: signature,
      );
      
      final smartWalletId = walletResult['id'];

      // 4. Start Nigeria Onboarding
      await BmoniApi.startNigeriaOnboarding(
        userId: _bmoniUserId!,
        bvn: _bvnCtrl.text,
        ngnWalletAddress: userOwnerAddress, // The proxy reuses this for fiat
        ngnWalletIndex: 0,
      );
      
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('business').insert({
        'owner_id': userId,
        'owner_bmoni_user_id': _bmoniUserId,
        'owner_wallet_id': smartWalletId, // Save the actual UUID, not the 0x address
        'name': _businessNameCtrl.text,
      });

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() => _statusMessage = "Error in Step 3: \$e");
    } finally {
      setState(() => _isLoading = false);
    }
  }
''';

  content = content.replaceAll(oldMethod.trim(), newMethod.trim());
  file.writeAsStringSync(content);
}
