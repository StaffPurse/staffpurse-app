import 'fund_wallet_screen.dart';
import '../services/bmoni_api.dart';
import 'package:flutter/material.dart';
import 'package:bkey_uikit/bkey_uikit.dart';
import 'package:bmoni_embedded_wallets_cards/bmoni_embedded_wallets_cards.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../env.dart';

import 'card_issuance_screen.dart';
import 'card_management_screen.dart';
import 'landing_screen.dart';
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
  bool _isProvisioning = false;
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

    Future<void> _pollProvisioning(String userId) async {
    // Cap at ~90 seconds (30 x 3s) so a stuck provisioning state can't poll
    // forever and drain the battery.
    var attempts = 0;
    while (_isProvisioning && mounted && attempts < 30) {
      attempts++;
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      try {
        final status = await BmoniApi.getOnboardingStatus(userId: userId);
        if (status['status']?['hasLocalWallet'] == true) {
          setState(() {
            _isProvisioning = false;
          });
          break;
        }
      } catch (e) {
        // keep polling
      }
    }
    // Give up after the cap so the staff list unblocks and cards stay tappable.
    if (mounted && _isProvisioning) {
      setState(() => _isProvisioning = false);
    }
  }

  Future<void> _fetchData() async {

    try {
      final businessRes = await _supabase.from('business')
          .select()
          .eq('owner_id', _supabase.auth.currentUser!.id)
          .maybeSingle();
      
      if (businessRes != null) {
        final staffRes = await _supabase.from('staff_member')
            .select('*, card_assignment(*)')
            .eq('business_id', businessRes['id'])
            .eq('status', 'active');

        final ownerUserId = businessRes['owner_bmoni_user_id'];
        final walletId = businessRes['owner_wallet_id'];

                // 3. Check if wallet is still provisioning
        try {
          final status = await BmoniApi.getOnboardingStatus(userId: ownerUserId);
          if (status['status']?['hasLocalWallet'] != true) {
            _isProvisioning = true;
            _pollProvisioning(ownerUserId);
          } else {
            _isProvisioning = false;
          }
        } catch (e) {
          // ignore
        }
        
        // 3a. ORPHAN RECONCILIATION: Sync any rogue cards from BMONI directly
        try {
          final liveCardsUrl = Uri.parse('${Env.bmoniBaseUrl}/users/$ownerUserId/smart-wallets/$walletId/cards');
          final liveCardsRes = await http.get(liveCardsUrl, headers: {
            "Content-Type": "application/json",
            "x-api-key": Env.bmoniApiKey,
          });
          
          if (liveCardsRes.statusCode >= 200 && liveCardsRes.statusCode < 300) {
            final liveCards = jsonDecode(liveCardsRes.body) as List<dynamic>;
            
            for (final liveCard in liveCards) {
              final bmoniId = liveCard['id'];
              // Check if we have this card in our local state
              bool existsLocally = staffRes.any((staff) {
                final cards = staff['card_assignment'] as List<dynamic>? ?? [];
                return cards.any((c) => c['bmoni_card_id'] == bmoniId);
              });

              if (!existsLocally) {
                // Orphan found! We would ideally assign it back to the right staff, but since 
                // BMONI doesn't know "staff", we might not know who it belongs to.
                // For the hackathon MVP, we just silently log it.
                print("Orphaned card found in BMONI: $bmoniId");
              }
            }
          }
        } catch (e) {
          // ignore reconciliation errors
        }

        // 3b. Sync transactions for all active cards in the background
        for (final staff in staffRes) {
          final cards = staff['card_assignment'] as List<dynamic>? ?? [];
          if (cards.isNotEmpty) {
            final card = cards.first;
            _cardService.syncTransactions(
              ownerUserId: ownerUserId,
              cardAssignmentId: card['id'],
              bmoniCardId: card['bmoni_card_id'],
            ).catchError((_) {}); 
          }
        }

        // Transactions are nice-to-have: a failure here (join error, schema
        // drift) must not blank out the whole dashboard.
        List<EmbeddedWalletTransaction> mappedTxs = [];
        try {
          final txRes = await _supabase.from('transaction_cache')
              .select('*, card_assignment!inner(staff_member!inner(name))')
              .order('occurred_at', ascending: false)
              .limit(20);

          mappedTxs = txRes.map((tx) {
            final koboAmount = tx['amount_ngn'] as int? ?? 0;
            final isDebit = koboAmount < 0;
            final majorAmount = (koboAmount.abs() / 100).toStringAsFixed(2);
            final staffName = tx['card_assignment']['staff_member']['name'];

            return EmbeddedWalletTransaction(
              id: tx['id'],
              direction: isDebit
                  ? EmbeddedTransactionDirection.outgoing
                  : EmbeddedTransactionDirection.incoming,
              delta: isDebit ? 'debit' : 'credit',
              amount: majorAmount,
              status: EmbeddedWalletTransactionStatus.completed,
              description: tx['description'] ?? 'Card Spend',
              title: staffName,
              createdAt: tx['occurred_at'],
              currency: 'NGN',
            );
          }).toList();
        } catch (e) {
          debugPrint('Transaction sync failed: $e');
        }

        double fetchedBalance = 0.0;
        try {
          final balances = await BmoniApi.getBalances(userId: ownerUserId);
          for (var b in balances) {
            final currency = (b['currency'] ?? '').toString();
            if (currency == 'CNGN' || currency == 'NGN') {
              fetchedBalance = double.tryParse(b['availableBalance']?.toString() ?? b['balance']?.toString() ?? b['amount']?.toString() ?? '0') ?? 0.0;
            }
          }
        } catch (e) {
          print('Error fetching balances: $e');
        }

        if (mounted) {
          setState(() {
            _business = businessRes;
            _staffCards = staffRes;
            _transactions = mappedTxs;
            _walletBalance = fetchedBalance;
          });
        }
      }
    } catch (e) {
      print('Fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildShimmerLoading() {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading Wallet...')),
      body: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 20, width: 150, color: Colors.white),
              const SizedBox(height: 16),
              Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 32),
              Container(height: 20, width: 100, color: Colors.white),
              const SizedBox(height: 16),
              Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              const SizedBox(height: 12),
              Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_business == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_rounded, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 24),
                const Text(
                  "No Business Found",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  "It looks like you haven't completed onboarding or the sandbox pre-warm script hasn't run.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _fetchData();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final wallet = EmbeddedWallet(
      walletId: _business!['owner_wallet_id'],
      walletIndex: 0,
      name: _business!['name'],
      currency: 'NGN',
      balance: _walletBalance,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_business!['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Fund Wallet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FundWalletScreen()),
              ).then((_) => _fetchData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            // Silent refresh: keep the current content on screen while
            // fetching instead of flashing the full shimmer again.
            onPressed: _fetchData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Main Business Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            EmbeddedWalletCard(wallet: wallet),
            const SizedBox(height: 32),
            const Text('Staff Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            if (_staffCards.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.group_off_rounded, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No staff members added yet.', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
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
                      : (_isProvisioning && !hasCard) ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_card),
                    onTap: () {
                      if (_isProvisioning && !hasCard) return;
                      if (hasCard) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CardManagementScreen(
                            ownerUserId: _business!['owner_bmoni_user_id'],
                            bmoniCardId: card['bmoni_card_id'],
                            staffId: staff['id'],
                            cardAssignmentId: card['id'],
                            currentDailyLimit: (card['daily_limit_ngn'] ?? 0) / 100, 
                            currentTxLimit: (card['per_transaction_limit_ngn'] ?? 0) / 100,
                            currentStatus: card['status'],
                            walletBalance: wallet.balance,
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
            EmbeddedWalletTransactionsSection(
              title: "Recent Staff Spending",
              emptyState: const Text("No recent transactions"),
              transactions: _transactions,
              itemBuilder: (context, tx) {
                final isDebit = tx.direction == EmbeddedTransactionDirection.outgoing;
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.payment)),
                  title: Text(tx.title ?? 'Spend'),
                  subtitle: Text(tx.description ?? ''),
                  trailing: Text(
                    '${isDebit ? '-' : '+'}₦${tx.amount}',
                    style: TextStyle(
                      color: isDebit ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


