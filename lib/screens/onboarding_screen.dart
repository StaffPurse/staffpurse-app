import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bmoni_embedded_sdk/bmoni_embedded_sdk.dart';
import '../services/onboarding_service.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _onboardingService = OnboardingService();

  final _businessNameCtrl = TextEditingController(text: "Acme Corp");
  final _firstNameCtrl = TextEditingController(text: "Test");
  final _lastNameCtrl = TextEditingController(text: "User");
  final _emailCtrl = TextEditingController(text: "test.user@staffpurse.local");
  final _phoneCtrl = TextEditingController(text: "+2348012345678");
  final _dobCtrl = TextEditingController(text: "1990-01-01");
  final _bvnCtrl = TextEditingController(text: "12345678901");
  final _ninCtrl = TextEditingController(text: "12345678901");
  final _pinCtrl = TextEditingController(text: "123456");

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingBusiness();
  }

  Future<void> _checkExistingBusiness() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final res = await Supabase.instance.client
          .from('business')
          .select()
          .eq('owner_id', user.id)
          .maybeSingle();

      if (res != null && mounted) {
        if (res['owner_wallet_id'] == 'PENDING_DEVICE_PROVISIONING') {
          // Prewarmed but missing hardware wallet keys!
          // We must stay on this screen to collect the PIN and run initWallet.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sandbox pre-warmed. Please enter a PIN and tap Onboard to initialize hardware keys.'),
              duration: Duration(seconds: 4),
            ),
          );
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // Business already exists and wallet is provisioned
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final res = await Supabase.instance.client
          .from('business')
          .select()
          .eq('owner_id', user.id)
          .maybeSingle();
      if (res != null && res['owner_wallet_id'] == 'PENDING_DEVICE_PROVISIONING') {
        if (!await BmoniEmbeddedSdk.hasPin()) {
          await BmoniEmbeddedSdk.setPin(_pinCtrl.text);
        }
        final walletAddress = await BmoniEmbeddedSdk.initWallet();
        await Supabase.instance.client.from('business').update({
          'owner_wallet_id': walletAddress
        }).eq('id', res['id']);

        const storage = FlutterSecureStorage();
        await storage.write(key: 'owner_nin', value: '12345678901'); // Sandbox dummy NIN

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
        return;
      }

      await _onboardingService.onboardOwner(
        businessName: _businessNameCtrl.text,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        email: _emailCtrl.text,
        phoneNumber: _phoneCtrl.text,
        dateOfBirth: _dobCtrl.text,
        bvn: _bvnCtrl.text,
        pin: _pinCtrl.text,
      );

      // Store NIN locally to be used when issuing the first card
      const storage = FlutterSecureStorage();
      await storage.write(key: 'owner_nin', value: _ninCtrl.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Onboarding successful!')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup StaffPurse')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BMoniTextFormField(controller: _businessNameCtrl, label: 'Business Name'),
              const SizedBox(height: 16),
              BMoniTextFormField(controller: _firstNameCtrl, label: 'First Name'),
              const SizedBox(height: 16),
              BMoniTextFormField(controller: _lastNameCtrl, label: 'Last Name'),
              const SizedBox(height: 16),
              BMoniTextFormField(controller: _emailCtrl, label: 'Email Address'),
              const SizedBox(height: 16),
              BMoniTextFormField(controller: _phoneCtrl, label: 'Phone Number (incl. +234)'),
              const SizedBox(height: 16),
              BMoniTextFormField(controller: _dobCtrl, label: 'Date of Birth (YYYY-MM-DD)'),
              const SizedBox(height: 16),
              BMoniTextFormField(controller: _bvnCtrl, label: 'BVN (11 digits)'),
              const SizedBox(height: 16),
              BMoniTextFormField(controller: _ninCtrl, label: 'NIN (11 digits)'),
              const SizedBox(height: 16),
              BMoniTextFormField(controller: _pinCtrl, label: '6-Digit Wallet PIN', obscureText: true),
              const SizedBox(height: 32),
              BMoniButton(
                onPressed: _submit,
                text: 'Complete Setup',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

