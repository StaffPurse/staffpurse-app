import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/bmoni_api.dart';
import '../services/user_facing_error.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _depositAccount;

  @override
  void initState() {
    super.initState();
    _fetchDepositAccount();
  }

  Future<void> _fetchDepositAccount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final business = await Supabase.instance.client
          .from('business')
          .select('owner_bmoni_user_id')
          .eq('owner_id', user.id)
          .single();

      final bmoniUserId = business['owner_bmoni_user_id'];
      
      final account = await BmoniApi.getDepositAccount(userId: bmoniUserId);
      if (mounted) {
        setState(() {
          _depositAccount = account;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = userFacingError(e);
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fund Wallet')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildAccountDetails(),
    );
  }

  Widget _buildAccountDetails() {
    final bankName = _depositAccount?['bankName'] ?? 'Providus Bank (BMONI)';
    final accountNumber = _depositAccount?['accountNumber'] ?? 'N/A';
    final accountName = _depositAccount?['accountName'] ?? 'StaffPurse Wallet';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.account_balance, size: 64, color: Colors.deepPurple),
          const SizedBox(height: 16),
          const Text(
            'Transfer to Virtual Account',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Send NGN to this dedicated bank account to automatically fund your StaffPurse Smart Wallet.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          _buildDetailRow('Bank Name', bankName),
          const SizedBox(height: 16),
          _buildDetailRow('Account Number', accountNumber, isCopyable: true),
          const SizedBox(height: 16),
          _buildDetailRow('Account Name', accountName),
          
          const SizedBox(height: 48),
          const Text(
            'Note: Transfers may take up to 5 minutes to reflect in your dashboard balance.',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isCopyable = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (isCopyable)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.deepPurple),
              onPressed: () => _copyToClipboard(value, label),
            ),
        ],
      ),
    );
  }
}
