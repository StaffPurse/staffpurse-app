import 'dart:io';

void main() {
  var file = File('lib/screens/onboarding_screen.dart');
  var content = file.readAsStringSync();
  
  var newClass = '''
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/onboarding_service.dart';
import '../services/bmoni_api.dart';
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
  final _bvnCtrl = TextEditingController();
  final _ninCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // BVN Verification State
  Timer? _bvnDebounce;
  bool _isVerifyingBvn = false;
  String? _bvnVerifiedName;
  String? _bvnError;

  @override
  void initState() {
    super.initState();
    // Prefill the email from Supabase Auth
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      _emailCtrl.text = user.email!;
    }

    _bvnCtrl.addListener(_onBvnChanged);
  }

  @override
  void dispose() {
    _bvnCtrl.removeListener(_onBvnChanged);
    _bvnDebounce?.cancel();
    _bvnCtrl.dispose();
    super.dispose();
  }

  void _onBvnChanged() {
    final text = _bvnCtrl.text.trim();
    if (text.length == 11) {
      if (_bvnDebounce?.isActive ?? false) _bvnDebounce!.cancel();
      _bvnDebounce = Timer(const Duration(milliseconds: 500), () {
        _verifyBvn(text);
      });
    } else {
      if (_bvnVerifiedName != null || _bvnError != null) {
        setState(() {
          _bvnVerifiedName = null;
          _bvnError = null;
        });
      }
    }
  }

  Future<void> _verifyBvn(String bvn) async {
    setState(() {
      _isVerifyingBvn = true;
      _bvnError = null;
      _bvnVerifiedName = null;
    });

    try {
      final res = await BmoniApi.bvnLookup(bvn: bvn);
      if (mounted) {
        setState(() {
          final firstName = res['firstName'] ?? '';
          final lastName = res['lastName'] ?? '';
          _bvnVerifiedName = "\$firstName \$lastName".trim();
          if (_bvnVerifiedName!.isEmpty) _bvnVerifiedName = "Verified";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bvnError = "Invalid BVN";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingBvn = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bvnVerifiedName == null) {
      setState(() => _errorMessage = "Please enter a valid 11-digit BVN and wait for verification.");
      return;
    }
    if (_ninCtrl.text.trim().length != 11) {
      setState(() => _errorMessage = "Please enter a valid 11-digit NIN.");
      return;
    }

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
      
      // Save actual NIN for sandbox testing / first card issuance
      const storage = FlutterSecureStorage();
      await storage.write(key: 'owner_nin', value: _ninCtrl.text.trim());

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
              
              // BVN FIELD WITH VERIFICATION UI
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BMoniTextField(
                    controller: _bvnCtrl, 
                    label: 'BVN (Use 22222222222 in Sandbox)',
                  ),
                  if (_isVerifyingBvn)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Verifying BVN...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    )
                  else if (_bvnVerifiedName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text('Verified: \$_bvnVerifiedName', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else if (_bvnError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          Text(_bvnError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    )
                ],
              ),
              const SizedBox(height: 16),
              
              BMoniTextField(controller: _ninCtrl, label: 'NIN (11 digits)'),
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
''';

  file.writeAsStringSync(newClass);
}
