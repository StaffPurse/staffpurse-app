import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';

import '../services/card_service.dart';

class CardManagementScreen extends StatefulWidget {
  final String ownerUserId;
  final String bmoniCardId;
  final String staffId;
  final String cardAssignmentId;
  final double currentDailyLimit;
  final double currentTxLimit;
  final String currentStatus;
  final double walletBalance;
  
  const CardManagementScreen({
    super.key,
    required this.ownerUserId,
    required this.bmoniCardId,
    required this.staffId,
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

    Future<void> _removeStaff() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff'),
        content: const Text('Are you sure you want to remove this staff member? This will permanently block their card and hide them from your dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _cardService.removeStaff(
        ownerUserId: widget.ownerUserId,
        staffId: widget.staffId,
        cardAssignmentId: widget.cardAssignmentId,
        bmoniCardId: widget.bmoniCardId,
      );
      if (mounted) {
        // The root ScaffoldMessenger survives the pop, so this confirmation
        // stays visible on the dashboard.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member removed and card blocked')),
        );
        Navigator.pop(context); // Go back to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLimits() async {
    setState(() => _isLoading = true);
    HapticFeedback.selectionClick();
    
    final daily = double.tryParse(_dailyLimitCtrl.text.trim());
    final tx = double.tryParse(_txLimitCtrl.text.trim());
    if (daily == null || tx == null || daily < 0 || tx < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid non-negative limits (NGN)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
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
              InfoCard(
                title: 'Card Status: ${_isFrozen ? 'FROZEN' : 'ACTIVE'}',
                message: 'Freeze to instantly block all transactions.',
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
            const SizedBox(height: 48),
            OutlinedButton(
              onPressed: _isLoading ? null : _removeStaff,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Remove Staff',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

      ),
    );
  }
}
