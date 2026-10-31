import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(
              'AI & Waste Analysis',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                  child: _buildWasteHeroCard(context, wastedTotal, wastedPct, txnProvider, isDark),
                ),
              ),

              // Breakdown of Wasted Spends by Category Pie
              if (analytics.wastedByApp.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _buildWastedPieCard(analytics.wastedByApp, wastedTotal, isDark),
                  ),
                ),

              // AI Suggestions: "What Expenses Can I Ignore / Cut Down?"
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.tips_and_updates, color: AppTheme.primaryColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Expenses You Can Cut Down',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (suggestions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Great job! No abnormal or high discretionary expenses detected.',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = suggestions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildSuggestionCard(item, txnProvider, isDark),
                        );
                      },
                      childCount: suggestions.length,
                    ),
                  ),
                ),

              // App-Wise Spending Leaderboard
              if (topApps.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Most Spent Apps (Amazon, Flipkart, etc.)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildAppLeaderboard(topApps, txnProvider, isDark),
                  ),
                ),
              ],

              // Bank Breakdown
              if (bankBreakdown.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(isDark ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.account_balance, color: AppTheme.secondaryColor, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Spending by Bank Account',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildBankList(bankBreakdown, txnProvider, isDark),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 110)),
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
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF3B0764), const Color(0xFF0F172A)]
              : [const Color(0xFFDC2626), const Color(0xFF991B1B)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(isDark ? 0.25 : 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
              Text(
                'WASTED MONEY (DISCRETIONARY)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${wastedPct.toStringAsFixed(0)}% of spends',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(wastedTotal),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Money consumed by food delivery, impulsive e-commerce, entertainment, and non-essential apps.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              txnProvider.setOnlyWastedFilter(true);
              onNavigateTab?.call(2); // Jump to Activity
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFDC2626),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.filter_alt_rounded, size: 16),
            label: const Text(
              'View All Wasted Spends',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWastedPieCard(Map<String, double> wastedByApp, double totalWaste, bool isDark) {
    if (wastedByApp.isEmpty || totalWaste <= 0) return const SizedBox.shrink();

    final sorted = wastedByApp.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF64748B),
    ];

    final sections = sorted.take(5).toList().asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      final pct = (entry.value / totalWaste) * 100;
      return PieChartSectionData(
        value: entry.value,
        color: colors[idx % colors.length],
        title: '${pct.toStringAsFixed(0)}%',
        radius: 35,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where Did Waste Money Go?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 28,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: sorted.take(4).toList().asMap().entries.map((e) {
                    final color = colors[e.key % colors.length];
                    final item = e.value;
                    final pct = (item.value / totalWaste) * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(0)}% • ${CurrencyFormatter.format(item.value)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(
    AiExpenseSuggestion item,
    TransactionProvider txnProvider,
    bool isDark,
  ) {
    Color badgeColor = const Color(0xFFEF4444);
    if (item.severity == 'medium') badgeColor = const Color(0xFFF59E0B);
    if (item.severity == 'low') badgeColor = const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Save ~${CurrencyFormatter.format(item.potentialSavings)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLeaderboard(
    List<AppSpendItem> topApps,
    TransactionProvider txnProvider,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: topApps.map((app) {
          return InkWell(
            onTap: () {
              txnProvider.setAppFilter(app.appName);
              onNavigateTab?.call(2); // Jump to Activity
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        app.appName.isNotEmpty ? app.appName[0] : '?',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryColor),
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
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${app.count} orders • ${app.percentage.toStringAsFixed(1)}% of total spends',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(app.totalSpent),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF64748B) : Colors.grey[400],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBankList(
    Map<String, Map<String, double>> bankBreakdown,
    TransactionProvider txnProvider,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: bankBreakdown.entries.map((entry) {
          final bank = entry.key;
          final debit = entry.value['debit'] ?? 0.0;
          final credit = entry.value['credit'] ?? 0.0;

          return InkWell(
            onTap: () {
              txnProvider.setBankFilter(bank);
              onNavigateTab?.call(2); // Jump to Activity
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance, color: AppTheme.secondaryColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '+${CurrencyFormatter.format(credit)} credit',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-${CurrencyFormatter.format(debit)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? const Color(0xFF64748B) : Colors.grey[400]),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
