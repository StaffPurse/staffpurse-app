import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'card_issuance_screen.dart';
import 'card_management_screen.dart';
import '../services/card_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  final _cardService = CardService();
  
  Map<String, dynamic>? _business;
  List<dynamic> _staffCards = [];
  List<EmbeddedWalletTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // 1. Fetch Business
      final businessRes = await _supabase.from('business').select().limit(1).maybeSingle();
      
      if (businessRes != null) {
        // 2. Fetch Staff + Cards (using join)
        final staffRes = await _supabase.from('staff_member')
            .select('*, card_assignment(*)')
            .eq('business_id', businessRes['id']);

        // 3. Sync transactions for all active cards in the background
        final ownerUserId = businessRes['owner_bmoni_user_id'];
        for (final staff in staffRes) {
          final cards = staff['card_assignment'] as List<dynamic>? ?? [];
          if (cards.isNotEmpty) {
            final card = cards.first;
            // Sync transactions gracefully in the background without blocking UI
            _cardService.syncTransactions(
              ownerUserId: ownerUserId,
              cardAssignmentId: card['id'],
              bmoniCardId: card['bmoni_card_id'],
            ).catchError((_) {}); 
          }
        }

        // 4. Fetch the merged transaction feed from our cache
        final txRes = await _supabase.from('transaction_cache')
            .select('*, card_assignment!inner(staff_member!inner(name))')
            .order('occurred_at', ascending: false)
            .limit(20);

        final mappedTxs = txRes.map((tx) {
          final koboAmount = tx['amount_ngn'] as int? ?? 0;
          final majorAmount = (koboAmount / 100).toStringAsFixed(2);
          final staffName = tx['card_assignment']['staff_member']['name'];

          return EmbeddedWalletTransaction(
            id: tx['id'],
            direction: EmbeddedTransactionDirection.outgoing, // Staff cards typically spend
            delta: 'debit',
            amount: majorAmount,
            status: EmbeddedWalletTransactionStatus.successful,
            description: tx['description'] ?? 'Card Spend',
            title: staffName,
            createdAt: tx['occurred_at'],
            currency: 'NGN',
          );
        }).toList();

        setState(() {
          _business = businessRes;
          _staffCards = staffRes;
          _transactions = mappedTxs;
        });
      }
    } catch (e) {
      print('Fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_business == null) {
      return const Scaffold(
        body: Center(child: Text("No business found. Please complete onboarding.")),
      );
    }

    final wallet = EmbeddedWallet(
      walletId: _business!['owner_wallet_id'],
      walletIndex: 0,
      name: _business!['name'],
      currency: 'NGN',
      balance: 150000.0, // Mock balance for demo since we didn't fetch live provider balance
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_business!['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchData();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Main Business Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Displays the Wallet View!
            EmbeddedWalletCard(wallet: wallet),
            
            const SizedBox(height: 32),
            const Text('Staff Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            ..._staffCards.map((staff) {
              final cards = staff['card_assignment'] as List<dynamic>? ?? [];
              final hasCard = cards.isNotEmpty;
              final card = hasCard ? cards.first : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(staff['name']),
                  subtitle: Text(hasCard ? 'Card: ${card['status'].toString().toUpperCase()}' : 'No card issued'),
                  trailing: hasCard 
                    ? const Icon(Icons.settings)
                    : const Icon(Icons.add_card),
                  onTap: () {
                    if (hasCard) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CardManagementScreen(
                          ownerUserId: _business!['owner_bmoni_user_id'],
                          bmoniCardId: card['bmoni_card_id'],
                          cardAssignmentId: card['id'],
                          currentDailyLimit: (card['daily_limit_ngn'] ?? 0) / 100, 
                          currentTxLimit: (card['per_transaction_limit_ngn'] ?? 0) / 100,
                          currentStatus: card['status'],
                        ),
                      )).then((_) => _fetchData());
                    } else {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CardIssuanceScreen(
                          businessId: _business!['id'],
                          ownerUserId: _business!['owner_bmoni_user_id'],
                          ownerWalletId: _business!['owner_wallet_id'],
                        ),
                      )).then((_) => _fetchData());
                    }
                  },
                ),
              );
            }),

            const SizedBox(height: 16),
            BMoniButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CardIssuanceScreen(
                    businessId: _business!['id'],
                    ownerUserId: _business!['owner_bmoni_user_id'],
                    ownerWalletId: _business!['owner_wallet_id'],
                  ),
                )).then((_) => _fetchData());
              },
              text: 'Add Staff Member',
              variant: BMoniButtonVariant.secondary,
            ),
            
            const SizedBox(height: 32),
            // Real Transaction Feed!
            EmbeddedWalletTransactionsSection(
              title: "Recent Staff Spending",
              emptyState: "No recent transactions",
              transactions: _transactions,
              itemBuilder: (context, tx) {
                // bmoni_embedded_wallets_cards typically has an internal builder if you don't override,
                // but if we must return a widget, we can return a ListTile
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.payment)),
                  title: Text(tx.title ?? 'Spend'),
                  subtitle: Text(tx.description ?? ''),
                  trailing: Text('- ₦${tx.amount}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

