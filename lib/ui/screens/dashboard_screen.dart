import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_card.dart';
import '../widgets/ios18_floating_tab_bar.dart';
import 'transactions_screen.dart';
import 'ai_waste_screen.dart';
import 'settings_screen.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  TransactionProvider? _transactionProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transactionProvider = context.read<TransactionProvider>();
      _transactionProvider?.addListener(_onTransactionUpdate);
      _refreshData();
    });
  }

  @override
  void dispose() {
    _transactionProvider?.removeListener(_onTransactionUpdate);
    super.dispose();
  }

  void _onTransactionUpdate() {
    if (mounted) {
      _refreshData();
    }
  }

  void _refreshData() {
    if (!mounted) return;
    
    final transactionProvider = context.read<TransactionProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();

    final dateRange = transactionProvider.getCurrentDateRange();
    final startDate = dateRange['start'];
    final endDate = dateRange['end'];

    var rangeTransactions = startDate != null && endDate != null
        ? transactionProvider.allTransactions.where((t) {
            return t.dateTime.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                   t.dateTime.isBefore(endDate.add(const Duration(seconds: 1)));
          }).toList()
        : transactionProvider.allTransactions;

    if (transactionProvider.selectedYear != null) {
      rangeTransactions = rangeTransactions
          .where((t) => t.dateTime.year == transactionProvider.selectedYear)
          .toList();
    }

    analyticsProvider.updateAnalytics(rangeTransactions);

    if (startDate != null && endDate != null) {
      final previousTransactions = AnalyticsProvider.getPreviousPeriodTransactions(
        transactionProvider.allTransactions,
        startDate,
        endDate,
      );

      analyticsProvider.updateWithComparison(
        rangeTransactions,
        previousTransactions,
      );
    }

    analyticsProvider.updateMonthlyTrend(
      transactionProvider.allTransactions,
      null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboardContent(),
      const TransactionsScreen(),
      AiWasteScreen(
        onNavigateTab: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: screens[_selectedIndex],
      bottomNavigationBar: Ios18FloatingTabBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            final tp = context.read<TransactionProvider>();
            tp.setTypeFilter(null);
            tp.setCategoryFilter(null);
            tp.setBankFilter(null);
            tp.setAppFilter(null);
            _refreshData();
          }
        },
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Consumer2<TransactionProvider, AnalyticsProvider>(
      builder: (context, transactionProvider, analyticsProvider, child) {
        if (transactionProvider.isLoading && transactionProvider.allTransactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await transactionProvider.syncFromSMS(limit: 200);
            if (mounted) _refreshData();
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // iOS 18 Styled App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: const Color(0xFFF6F8FA).withOpacity(0.9),
                elevation: 0,
                title: Row(
                  children: [
                    Text(
                      'FinTracker',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xFF6366F1),
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: transactionProvider.isSyncing
                          ? const Color(0xFF6366F1)
                          : Colors.black87,
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await transactionProvider.syncFromSMS(limit: 200);
                      if (mounted) _refreshData();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.black87),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AddTransactionScreen(),
                        ),
                      ).then((_) => _refreshData());
                    },
                  ),
                ],
              ),

              // Filter Controls: Year Selector & Period Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Column(
                    children: [
                      _buildYearAndPeriodSelector(transactionProvider),
                    ],
                  ),
                ),
              ),

              // Modern Hero Card: Balance & Income/Expense Pill
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildHeroBalanceCard(context, analyticsProvider, transactionProvider),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // Waste of Money Banner (Direct Call-to-action)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildWasteBanner(context, analyticsProvider),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // Top Spending Apps Leaderboard
              if (analyticsProvider.topApps.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildTopAppsCard(context, analyticsProvider, transactionProvider),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // AI Insights Section
              if (analyticsProvider.insights.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildInsightsCard(analyticsProvider.insights),
                  ),
                ),

              // Recent Transactions Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIndex = 1;
                          });
                        },
                        child: const Text('View All →'),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Transactions List
              transactionProvider.filteredTransactions.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 10),
                              Text(
                                'No transactions recorded',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= 6) return null;
                          final transaction = transactionProvider.filteredTransactions[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: TransactionCard(transaction: transaction),
                          );
                        },
                        childCount: transactionProvider.filteredTransactions.length > 6
                            ? 6
                            : transactionProvider.filteredTransactions.length,
                      ),
                    ),

              // Bottom padding for the floating navigation bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroBalanceCard(
    BuildContext context,
    AnalyticsProvider analytics,
    TransactionProvider txnProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withOpacity(0.35),
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
              Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  txnProvider.selectedYear != null
                      ? 'Year ${txnProvider.selectedYear}'
                      : _formatRangeLabel(txnProvider.dateRangeType),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(analytics.balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Income Pill
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_downward, color: Color(0xFF34D399), size: 14),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Income',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          ),
                          Text(
                            CurrencyFormatter.formatCompact(analytics.totalIncome),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Expense Pill
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_upward, color: Color(0xFFF87171), size: 14),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spent',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          ),
                          Text(
                            CurrencyFormatter.formatCompact(analytics.totalExpense),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWasteBanner(BuildContext context, AnalyticsProvider analytics) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = 2; // Jump to AI & Waste tab
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFECDD3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Waste of Money: ',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        CurrencyFormatter.format(analytics.uselessSpends),
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${analytics.uselessSpendPercentage.toStringAsFixed(0)}% of spent went to non-essentials. Tap for AI tips →',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFEF4444), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppsCard(
    BuildContext context,
    AnalyticsProvider analytics,
    TransactionProvider txnProvider,
  ) {
    final top3 = analytics.topApps.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
              const Row(
                children: [
                  Icon(Icons.apps_rounded, color: Color(0xFF3B82F6), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Top Spent Apps',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = 2; // Jump to AI & Waste tab
                  });
                },
                child: const Text(
                  'See All Apps →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...top3.map((app) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    app.appName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyFormatter.format(app.totalSpent),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildYearAndPeriodSelector(TransactionProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Year Selection Dropdown / Pill
          PopupMenuButton<int?>(
            onSelected: (year) {
              provider.setYearFilter(year);
              _refreshData();
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem<int?>(
                  value: null,
                  child: Text('All Years'),
                ),
                ...provider.availableYears.map((y) {
                  return PopupMenuItem<int?>(
                    value: y,
                    child: Text('Year $y'),
                  );
                }),
              ];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: provider.selectedYear != null
                    ? const Color(0xFF6366F1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: provider.selectedYear != null
                      ? const Color(0xFF6366F1)
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: provider.selectedYear != null ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.selectedYear != null
                        ? '${provider.selectedYear}'
                        : 'Year: All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: provider.selectedYear != null ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: provider.selectedYear != null ? Colors.white : Colors.black54,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Period Chips
          _buildDateRangeChip('Today', DateRangeType.today, provider),
          const SizedBox(width: 6),
          _buildDateRangeChip('Week', DateRangeType.week, provider),
          const SizedBox(width: 6),
          _buildDateRangeChip('Month', DateRangeType.month, provider),
          const SizedBox(width: 6),
          _buildDateRangeChip('6M', DateRangeType.sixMonths, provider),
          const SizedBox(width: 6),
          _buildDateRangeChip('1Y', DateRangeType.year, provider),
          const SizedBox(width: 6),
          _buildDateRangeChip('All', DateRangeType.all, provider),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip(
    String label,
    DateRangeType type,
    TransactionProvider provider,
  ) {
    final isSelected = provider.dateRangeType == type && provider.selectedYear == null;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        provider.setYearFilter(null);
        provider.setDateRange(type);
        _refreshData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1B4B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E1B4B) : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsCard(List<String> insights) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 8),
              Text(
                'AI Financial Insights',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.take(3).map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  insight,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.35,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  String _formatRangeLabel(DateRangeType type) {
    switch (type) {
      case DateRangeType.today:
        return 'Today';
      case DateRangeType.week:
        return 'This Week';
      case DateRangeType.month:
        return 'This Month';
      case DateRangeType.sixMonths:
        return 'Last 6 Months';
      case DateRangeType.year:
        return 'Last 1 Year';
      case DateRangeType.all:
        return 'All Time';
      case DateRangeType.custom:
        return 'Custom';
    }
  }
}
