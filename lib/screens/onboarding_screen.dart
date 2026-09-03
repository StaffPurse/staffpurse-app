import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import '../services/onboarding_service.dart';
import 'dashboard_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefill the email from Supabase Auth
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      _emailCtrl.text = user.email!;
    }
  }
  final _bvnCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = OnboardingService();
      await service.onboardOwner(
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        email: _emailCtrl.text,
        phoneNumber: _phoneCtrl.text,
        bvn: _bvnCtrl.text,
        businessName: _businessNameCtrl.text,
        pin: _pinCtrl.text,
      );
      
      // Save dummy NIN for sandbox testing (since NGN doesn't ask for it during start-nigeria, but cards API requires it)
      const storage = FlutterSecureStorage();
      await storage.write(key: 'owner_nin', value: '12345678901');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup StaffPurse')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 24),
                  color: Colors.red.shade100,
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
                
              const Text('Personal Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              BMoniTextField(controller: _firstNameCtrl, label: 'First Name'),
              const SizedBox(height: 16),
              BMoniTextField(controller: _lastNameCtrl, label: 'Last Name'),
              const SizedBox(height: 16),
              BMoniTextField(controller: _emailCtrl, label: 'Email'),
              const SizedBox(height: 16),
              BMoniTextField(controller: _phoneCtrl, label: 'Phone (+234...)'),
              const SizedBox(height: 16),
              BMoniTextField(controller: _bvnCtrl, label: 'BVN (Use 22222222222 in Sandbox)'),
              const SizedBox(height: 32),
              
              const Text('Business Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              BMoniTextField(controller: _businessNameCtrl, label: 'Business Name'),
              const SizedBox(height: 16),
              BMoniTextField(controller: _pinCtrl, label: 'Wallet PIN (6 digits)', obscureText: true),
              const SizedBox(height: 32),
              
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : BMoniButton(
                    onPressed: _submit,
                    text: 'Complete Setup',
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
