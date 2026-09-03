import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/onboarding_service.dart';
import '../services/bmoni_api.dart';
import 'dashboard_screen.dart';

class KycScreen extends StatefulWidget {
  final String bmoniUserId;
  const KycScreen({super.key, required this.bmoniUserId});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _bvnCtrl = TextEditingController();
  final _ninCtrl = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _bvnDebounce;
  bool _isVerifyingBvn = false;
  String? _bvnVerifiedName;
  String? _bvnError;

  @override
  void initState() {
    super.initState();
    _bvnCtrl.addListener(_onBvnChanged);
  }

  @override
  void dispose() {
    _bvnCtrl.removeListener(_onBvnChanged);
    _bvnDebounce?.cancel();
    _bvnCtrl.dispose();
    _ninCtrl.dispose();
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
      final res = await BmoniApi.bvnLookup(
        userId: widget.bmoniUserId, // We now pass the exact user ID created in Stage 1!
        bvn: bvn
      );
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
          _bvnError = "Invalid BVN or verification failed";
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
      // 1. Fire Nigeria Onboarding
      final service = OnboardingService();
      await service.activateKyc(
        bmoniUserId: widget.bmoniUserId,
        bvn: _bvnCtrl.text.trim(),
      );
      
      // 2. Save actual NIN for sandbox testing / first card issuance
      const storage = FlutterSecureStorage();
      await storage.write(key: 'owner_nin', _ninCtrl.text.trim());

      // 3. Drop into dashboard where async provisioning UI will handle the wait
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
      appBar: AppBar(title: const Text('Activate Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Verify Identity', 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            const Text(
              'Your BMONI profile and Smart Wallet are ready. Provide your BVN and NIN to activate the Nigerian Naira (NGN) rail.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 24),
                color: Colors.red.shade100,
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
              
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BMoniTextFormField(
                  controller: _bvnCtrl, 
                  label: 'BVN (Use 22222222222 in Sandbox)',
                ),
                if (_isVerifyingBvn)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Verifying BVN against national registry...', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
            
            BMoniTextFormField(controller: _ninCtrl, label: 'NIN (11 digits)'),
            const SizedBox(height: 32),
            
            _isLoading
              ? const Center(child: CircularProgressIndicator())
              : BMoniButton(
                  onPressed: _submit,
                  text: 'Activate NGN Rail',
                ),
          ],
        ),
      ),
    );
  }
}
