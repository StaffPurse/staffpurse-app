import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/card_service.dart';

class CardManagementScreen extends StatefulWidget {
  final String ownerUserId;
  final String bmoniCardId;
  final String cardAssignmentId;
  final double currentDailyLimit;
  final double currentTxLimit;
  final String currentStatus;
  
  const CardManagementScreen({
    super.key,
    required this.ownerUserId,
    required this.bmoniCardId,
    required this.cardAssignmentId,
    required this.currentDailyLimit,
    required this.currentTxLimit,
    required this.currentStatus,
  });

  @override
  State<CardManagementScreen> createState() => _CardManagementScreenState();
}

class _CardManagementScreenState extends State<CardManagementScreen> {
  final _cardService = CardService();
  bool _isLoading = false;
  late bool _isFrozen;

  late TextEditingController _dailyLimitCtrl;
  late TextEditingController _txLimitCtrl;

  @override
  void initState() {
    super.initState();
    _isFrozen = widget.currentStatus.toLowerCase() == 'frozen';
    _dailyLimitCtrl = TextEditingController(text: widget.currentDailyLimit.toStringAsFixed(0));
    _txLimitCtrl = TextEditingController(text: widget.currentTxLimit.toStringAsFixed(0));
  }

  Future<void> _toggleFreeze() async {
    setState(() => _isLoading = true);
    try {
      await _cardService.toggleCardFreeze(
        ownerUserId: widget.ownerUserId,
        cardAssignmentId: widget.cardAssignmentId,
        bmoniCardId: widget.bmoniCardId,
        freeze: !_isFrozen,
      );
      setState(() => _isFrozen = !_isFrozen);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isFrozen ? 'Card frozen' : 'Card active')),
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

  Future<void> _updateLimits() async {
    setState(() => _isLoading = true);
    try {
      final daily = double.parse(_dailyLimitCtrl.text);
      final tx = double.parse(_txLimitCtrl.text);

      await _cardService.setCardLimits(
        ownerUserId: widget.ownerUserId,
        cardAssignmentId: widget.cardAssignmentId,
        bmoniCardId: widget.bmoniCardId,
        dailyLimit: daily,
        transactionLimit: tx,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Limits updated successfully')),
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
      appBar: AppBar(title: const Text('Manage Card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BMoniInfoCard(
              title: 'Card Status: ${_isFrozen ? 'FROZEN' : 'ACTIVE'}',
              description: 'Freeze to instantly block all transactions.',
            ),
            const SizedBox(height: 16),
            BMoniButton(
              onPressed: _isLoading ? null : _toggleFreeze,
              text: _isFrozen ? 'Unfreeze Card' : 'Freeze Card',
              variant: _isFrozen ? BMoniButtonVariant.primary : BMoniButtonVariant.secondary,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 32),
            const Text('Set Limits (NGN)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            BMoniTextFormField(
              controller: _dailyLimitCtrl,
              label: 'Daily Limit',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            BMoniTextFormField(
              controller: _txLimitCtrl,
              label: 'Per Transaction Limit',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            BMoniButton(
              onPressed: _isLoading ? null : _updateLimits,
              text: 'Save Limits',
              isLoading: _isLoading,
            ),
          ],
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
      color: Colors.blueGrey.shade50,
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
