import 'landing_screen.dart';
import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/onboarding_service.dart';
import '../services/user_facing_error.dart';
import '../widgets/error_banner.dart';
import 'kyc_screen.dart';

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
  final _phoneCtrl = TextEditingController(text: '+234');
  final _businessNameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      _emailCtrl.text = user.email!;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = OnboardingService();
      final res = await service.setupProfileAndWallet(
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        email: _emailCtrl.text,
        phoneNumber: _phoneCtrl.text.replaceAll(' ', ''),
        businessName: _businessNameCtrl.text,
        pin: _pinCtrl.text,
      );
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => KycScreen(bmoniUserId: res['bmoniUserId']!)),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = userFacingError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
        title: const Text('Setup Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                // Return to AuthScreen/LandingScreen cleanly
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingScreen()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                ErrorBanner(message: _errorMessage!),
                
              const Text('Personal Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _firstNameCtrl,
                label: 'First Name',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _lastNameCtrl,
                label: 'Last Name',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _emailCtrl,
                label: 'Email',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _phoneCtrl,
                label: 'Phone',
                keyboardType: TextInputType.phone,
                helperText: 'Start with +234 (e.g. +2348012345678)',
                validator: (v) {
                  final t = (v ?? '').replaceAll(' ', '');
                  if (t.isEmpty) return 'Phone number is required';
                  if (!RegExp(r'^\+234\d{10}$').hasMatch(t)) {
                    return 'Enter as +234 followed by 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              const Text('Business Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _businessNameCtrl,
                label: 'Business Name',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _pinCtrl,
                label: 'Wallet PIN (6 digits)',
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.length != 6 || int.tryParse(v) == null) {
                    return 'PIN must be exactly 6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : BMoniButton(
                    onPressed: _submit,
                    text: 'Create Wallet',
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
