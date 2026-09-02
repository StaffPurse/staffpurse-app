import 'package:flutter/material.dart';
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
      final nin = await storage.read(key: 'owner_nin') ?? '';

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
                const BMoniInfoCard(
                  title: 'Card Reserved',
                  description: 'Awaiting secure signature from device hardware...',
                  // using basic styling if BMoniInfoCard doesn't exist, wait, uikit has info_card.dart
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
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _staffPhoneCtrl,
                label: 'Staff Phone',
                enabled: _cardStatus == 'NOT_ISSUED',
              ),
              const SizedBox(height: 16),
              BMoniTextFormField(
                controller: _pinCtrl,
                label: 'Your 6-Digit Owner PIN (to sign)',
                obscureText: true,
                enabled: _cardStatus == 'NOT_ISSUED',
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

// A simple fallback widget just in case BMoniInfoCard has a different signature.
class BMoniInfoCard extends StatelessWidget {
  final String title;
  final String description;
  const BMoniInfoCard({super.key, required this.title, required this.description});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.amber.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description),
        ],
      ),
    );
  }
}
