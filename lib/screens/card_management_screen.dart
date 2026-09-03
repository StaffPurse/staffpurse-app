import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';

import '../services/card_service.dart';

class CardManagementScreen extends StatefulWidget {
  final String ownerUserId;
  final String bmoniCardId;
  final String cardAssignmentId;
  final double currentDailyLimit;
  final double currentTxLimit;
  final String currentStatus;
  final double walletBalance;
  
  const CardManagementScreen({
    super.key,
    required this.ownerUserId,
    required this.bmoniCardId,
    required this.cardAssignmentId,
    required this.currentDailyLimit,
    required this.currentTxLimit,
    required this.currentStatus,
    required this.walletBalance,
  });

  @override
  State<CardManagementScreen> createState() => _CardManagementScreenState();
}

class _CardManagementScreenState extends State<CardManagementScreen> {
  final _cardService = CardService();
  bool _isLoading = false;
  late bool _isFrozen;
  late bool _isIrreversibleStatus;

  late TextEditingController _dailyLimitCtrl;
  late TextEditingController _txLimitCtrl;

  @override
  void initState() {
    super.initState();
    final status = widget.currentStatus.toLowerCase();
    _isFrozen = status == 'frozen' || status == 'blocked';
    
    // Check if the card is in a state we can't safely toggle (e.g., stolen, restricted, deactivated)
    _isIrreversibleStatus = !['active', 'frozen', 'blocked', 'pending'].contains(status);

    _dailyLimitCtrl = TextEditingController(text: widget.currentDailyLimit.toStringAsFixed(0));
    _txLimitCtrl = TextEditingController(text: widget.currentTxLimit.toStringAsFixed(0));
  }

  Future<void> _toggleFreeze() async {
    final originalState = _isFrozen;
    
    // 1. Optimistic UI Update & Haptic
    setState(() => _isFrozen = !_isFrozen);
    HapticFeedback.mediumImpact();

    try {
      await _cardService.toggleCardFreeze(
        ownerUserId: widget.ownerUserId,
        cardAssignmentId: widget.cardAssignmentId,
        bmoniCardId: widget.bmoniCardId,
        freeze: _isFrozen,
      );
      // Success! Network matched our optimistic state.
    } catch (e) {
      // 2. Revert on failure
      if (mounted) {
        setState(() => _isFrozen = originalState);
        HapticFeedback.heavyImpact(); // Alert user of failure
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateLimits() async {
    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();
    
    try {
      final daily = double.parse(_dailyLimitCtrl.text);
      final tx = double.parse(_txLimitCtrl.text);

      if (daily > widget.walletBalance) {
        // Edge Case: Setting a limit higher than liquid balance. The provider allows it, 
        // but we should explicitly warn the user.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Daily limit exceeds current wallet balance. Transactions may decline.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      await _cardService.setCardLimits(
        ownerUserId: widget.ownerUserId,
        cardAssignmentId: widget.cardAssignmentId,
        bmoniCardId: widget.bmoniCardId,
        dailyLimit: daily,
        transactionLimit: tx,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Limits updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
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
            if (_isIrreversibleStatus)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red.shade50,
                child: Text(
                  'Card is currently ${widget.currentStatus.toUpperCase()}. This state was set by the issuer and cannot be reversed from the app.',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              )
            else
              BMoniInfoCard(
                title: 'Card Status: ${_isFrozen ? 'FROZEN' : 'ACTIVE'}',
                description: 'Freeze to instantly block all transactions.',
              ),
            
            const SizedBox(height: 16),
            
            BMoniButton(
              onPressed: (_isLoading || _isIrreversibleStatus) ? null : _toggleFreeze,
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
