import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/analytics_service.dart';

class AiWasteScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateTab;

  const AiWasteScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF6366F1), size: 22),
            SizedBox(width: 8),
            Text(
              'AI & Waste Analysis',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
      body: Consumer2<TransactionProvider, AnalyticsProvider>(
        builder: (context, txnProvider, analytics, child) {
          final topApps = analytics.topApps;
          final suggestions = analytics.smartSuggestions;
          final wastedTotal = analytics.uselessSpends;
          final wastedPct = analytics.uselessSpendPercentage;
          final bankBreakdown = analytics.bankBreakdown;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero: Waste of Money Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildWasteHeroCard(context, wastedTotal, wastedPct, txnProvider),
                ),
              ),

              // AI Suggestions: "What Expenses Can I Ignore / Cut Down?"
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.tips_and_updates, color: Color(0xFF6366F1), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Expenses You Can Cut Down',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              if (suggestions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF10B981)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Great job! No excessive or wasteful spending detected for this period.',
                              style: TextStyle(fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = suggestions[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        child: _buildSuggestionCard(context, item),
                      );
                    },
                    childCount: suggestions.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // App Leaderboard: "Which App Mostly Spent Money"
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.apps_rounded, color: Color(0xFF3B82F6), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Most Spent Apps & Services',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      if (txnProvider.selectedApp != null)
                        GestureDetector(
                          onTap: () => txnProvider.setAppFilter(null),
                          child: const Text(
                            'Clear Filter',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              if (topApps.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text('No app spending data available yet.'),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final app = topApps[index];
                      final isSelected = txnProvider.selectedApp?.toLowerCase() == app.appName.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: _buildAppSpendRow(context, app, isSelected, txnProvider),
                      );
                    },
                    childCount: topApps.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Bank Breakdown Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      Icon(Icons.account_balance_rounded, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Spending by Bank Account',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              if (bankBreakdown.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text('No bank transaction data available.'),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = bankBreakdown.entries.toList()[index];
                      final bank = entry.key;
                      final debit = entry.value['debit'] ?? 0.0;
                      final credit = entry.value['credit'] ?? 0.0;
                      final isSelected = txnProvider.selectedBank == bank;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: _buildBankRow(context, bank, debit, credit, isSelected, txnProvider),
                      );
                    },
                    childCount: bankBreakdown.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWasteHeroCard(
    BuildContext context,
    double wastedTotal,
    double wastedPct,
    TransactionProvider txnProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5252), Color(0xFFFF7A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5252).withOpacity(0.32),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Waste of Money',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  txnProvider.setOnlyWastedFilter(!txnProvider.onlyWastedSpends);
                  if (onNavigateTab != null) onNavigateTab!(1);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    txnProvider.onlyWastedSpends ? 'Showing Wasted' : 'View Items',
                    style: const TextStyle(
                      color: Color(0xFFFF5252),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            CurrencyFormatter.format(wastedTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${wastedPct.toStringAsFixed(1)}% of your expenses went to non-essentials (Food delivery, impulsive online shopping, entertainment & unused subscriptions).',
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(BuildContext context, AiExpenseSuggestion item) {
    Color accentColor = const Color(0xFFF59E0B);
    if (item.severity == 'high') {
      accentColor = const Color(0xFFEF4444);
    } else if (item.severity == 'low') {
      accentColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Save ~₹${item.potentialSavings.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSpendRow(
    BuildContext context,
    AppSpendItem app,
    bool isSelected,
    TransactionProvider txnProvider,
  ) {
    return GestureDetector(
      onTap: () {
        if (isSelected) {
          txnProvider.setAppFilter(null);
        } else {
          txnProvider.setAppFilter(app.appName);
          if (onNavigateTab != null) onNavigateTab!(1);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1).withOpacity(0.4)
                : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _getAppColor(app.appName).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      app.appName.isNotEmpty ? app.appName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _getAppColor(app.appName),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${app.count} transactions • ${app.percentage.toStringAsFixed(1)}% of expenses',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(app.totalSpent),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    const Text(
                      'Filter by app →',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (app.percentage / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[100],
                valueColor: AlwaysStoppedAnimation<Color>(_getAppColor(app.appName)),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankRow(
    BuildContext context,
    String bank,
    double debit,
    double credit,
    bool isSelected,
    TransactionProvider txnProvider,
  ) {
    return GestureDetector(
      onTap: () {
        if (isSelected) {
          txnProvider.setBankFilter(null);
        } else {
          txnProvider.setBankFilter(bank);
          if (onNavigateTab != null) onNavigateTab!(1);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF10B981).withOpacity(0.4)
                : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.account_balance, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Debited: ₹${debit.toStringAsFixed(0)} | Credited: ₹${credit.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.chevron_right,
              color: isSelected ? const Color(0xFF10B981) : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _getAppColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('swiggy')) return const Color(0xFFFF5200);
    if (lower.contains('zomato')) return const Color(0xFFE23744);
    if (lower.contains('amazon')) return const Color(0xFFFF9900);
    if (lower.contains('flipkart')) return const Color(0xFF2874F0);
    if (lower.contains('blinkit')) return const Color(0xFFF4C430);
    if (lower.contains('zepto')) return const Color(0xFF8B5CF6);
    if (lower.contains('uber')) return const Color(0xFF000000);
    if (lower.contains('ola')) return const Color(0xFF10B981);
    if (lower.contains('netflix')) return const Color(0xFFE50914);
    if (lower.contains('spotify')) return const Color(0xFF1DB954);
    return const Color(0xFF6366F1);
  }
}
