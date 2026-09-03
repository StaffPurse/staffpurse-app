import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import '../services/bmoni_api.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _supabase = Supabase.instance.client;
  
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bvnCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();

  String _statusMessage = "Ready to start (Build V3)";
  bool _isLoading = false;
  
  String? _bmoniUserId;

  Future<void> _step1CreateUser() async {
    setState(() { _isLoading = true; _statusMessage = "Step 1: Creating BMONI User..."; });
    try {
      final payload = {
        "firstName": _firstNameCtrl.text,
        "lastName": _lastNameCtrl.text,
        "email": _emailCtrl.text,
        "phoneNumber": _phoneCtrl.text,
      };
      setState(() => _statusMessage = "Sending payload: $payload");
      
      final userId = await BmoniApi.createUserOnly(
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        email: _emailCtrl.text,
        phoneNumber: _phoneCtrl.text,
      );
      
      setState(() {
        _bmoniUserId = userId;
        _statusMessage = "Success! User ID: $userId";
      });
    } catch (e) {
      setState(() => _statusMessage = "Error in Step 1: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _step2ActivateKyc() async {
    if (_bmoniUserId == null) return;
    setState(() { _isLoading = true; _statusMessage = "Step 2: Activating KYC..."; });
    try {
      await BmoniApi.activateKycOnly(
        userId: _bmoniUserId!,
        dateOfBirth: _dobCtrl.text,
        bvn: _bvnCtrl.text,
      );
      setState(() => _statusMessage = "KYC Activated Successfully!");
    } catch (e) {
      setState(() => _statusMessage = "Error in Step 2: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
      setState(() => _statusMessage = "Error in Step 3: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup StaffPurse (Debug)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.yellow.shade100,
              child: Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
            const SizedBox(height: 16),
            TextField(controller: _businessNameCtrl, decoration: const InputDecoration(labelText: 'Business Name')),
            TextField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name')),
            TextField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)')),
            TextField(controller: _bvnCtrl, decoration: const InputDecoration(labelText: 'BVN (Use 22222222222 for test)')),
            TextField(controller: _pinCtrl, decoration: const InputDecoration(labelText: '6-digit PIN')),
            
            const SizedBox(height: 24),
            if (_isLoading) const CircularProgressIndicator()
            else Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(onPressed: _step1CreateUser, child: const Text('1. Create BMONI User')),
                ElevatedButton(onPressed: _bmoniUserId != null ? _step2ActivateKyc : null, child: const Text('2. Activate KYC')),
                ElevatedButton(onPressed: _bmoniUserId != null ? _step3SetupWallet : null, child: const Text('3. Setup Wallet & Finish')),
              ],
            )
          ],
        ),
      ),
    );
  }
}
