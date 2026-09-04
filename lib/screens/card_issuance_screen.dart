import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/card_service.dart';

class CardIssuanceScreen extends StatefulWidget {
  final String ownerUserId;
  final String ownerWalletId;
  final String businessId;

  const CardIssuanceScreen({
    super.key,
    required this.ownerUserId,
    required this.ownerWalletId,
    required this.businessId,
  });

  @override
  State<CardIssuanceScreen> createState() => _CardIssuanceScreenState();
}

class _CardIssuanceScreenState extends State<CardIssuanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardService = CardService();

  final _staffNameCtrl = TextEditingController();
  final _staffPhoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _isLoading = false;
  String _cardStatus = 'NOT_ISSUED'; // NOT_ISSUED, RESERVED, ISSUED

  Future<void> _issueCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _cardStatus = 'RESERVED'; // UI state while signing
    });

    try {
      const storage = FlutterSecureStorage();
      String nin = await storage.read(key: 'owner_nin') ?? '';
      
      // Fallback for Demo: If the user ran the prewarm script and skipped onboarding, 
      // the secure storage will be empty. We inject the sandbox dummy NIN.
      if (nin.isEmpty) {
        nin = '12345678901';
      }

      await _cardService.addStaffAndIssueCard(
        businessId: widget.businessId,
        ownerUserId: widget.ownerUserId,
        ownerWalletId: widget.ownerWalletId,
        staffName: _staffNameCtrl.text,
        staffPhone: _staffPhoneCtrl.text,
        pin: _pinCtrl.text,
        nin: nin,
      );

      if (mounted) {
        setState(() {
          _cardStatus = 'ISSUED';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card issued successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cardStatus = 'NOT_ISSUED';
        });
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
      appBar: AppBar(title: const Text('Issue Staff Card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_cardStatus == 'RESERVED') ...[
                const InfoCard(
                  title: 'Card Reserved',
                  message: 'Awaiting secure signature from device hardware...',
                ),
                const SizedBox(height: 24),
              ],
              if (_cardStatus == 'ISSUED') ...[
                const Text('Card is ready and assigned!', style: TextStyle(color: Colors.green)),
                const SizedBox(height: 24),
              ],
              BMoniTextFormField(
                controller: _staffNameCtrl,
                label: 'Staff Name',
                enabled: _cardStatus == 'NOT_ISSUED',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Staff name is required' : null,
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _staffPhoneCtrl,
                label: 'Staff Phone',
                keyboardType: TextInputType.phone,
                enabled: _cardStatus == 'NOT_ISSUED',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone number is required' : null,
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _pinCtrl,
                label: 'Your 6-Digit Owner PIN (to sign)',
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                enabled: _cardStatus == 'NOT_ISSUED',
                validator: (v) {
                  final t = v ?? '';
                  if (t.length != 6) return 'PIN must be exactly 6 digits';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              if (_cardStatus == 'NOT_ISSUED' || _cardStatus == 'RESERVED')
                BMoniButton(
                  onPressed: _issueCard,
                  text: 'Issue Virtual Card',
                  isLoading: _isLoading,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
