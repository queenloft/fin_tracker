import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/transaction_card.dart';
import '../widgets/ios18_floating_tab_bar.dart';
import 'analytics_screen.dart';
import 'transactions_screen.dart';
import 'ai_waste_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final List<int> _navigationHistory = [0]; // tracks tab navigation for hardware Back button
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

  void _navigateToTab(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _navigationHistory.add(index);
    });
    if (index == 0) {
      final tp = context.read<TransactionProvider>();
      tp.setTypeFilter(null);
      tp.setCategoryFilter(null);
      tp.setBankFilter(null);
      tp.setAppFilter(null);
      _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboardContent(),
      AnalyticsScreen(
        onNavigateTab: (index) => _navigateToTab(index),
      ),
      const TransactionsScreen(),
      AiWasteScreen(
        onNavigateTab: (index) => _navigateToTab(index),
      ),
      const SettingsScreen(),
    ];

    // PopScope intercepts Android Back button so app doesn't immediately close
    return PopScope(
      canPop: _selectedIndex == 0 && _navigationHistory.length <= 1,
      onPopInvoked: (didPop) {
        if (didPop) return;

        // If currently on any subtab (e.g. Activity, Analytics, Waste, Settings), pop back to Dashboard
        if (_navigationHistory.length > 1) {
          setState(() {
            _navigationHistory.removeLast();
            _selectedIndex = _navigationHistory.last;
          });
        } else if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
            _navigationHistory.clear();
            _navigationHistory.add(0);
          });
        }
      },
      child: Scaffold(
        extendBody: true,
        body: screens[_selectedIndex],
        bottomNavigationBar: Ios18FloatingTabBar(
          selectedIndex: _selectedIndex,
          onTabSelected: (index) => _navigateToTab(index),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

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
                backgroundColor: bg.withOpacity(0.9),
                elevation: 0,
                title: Row(
                  children: [
                    Text(
                      'FinTracker',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.6,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Year Filter Dropdown Pill
                  PopupMenuButton<int?>(
                    initialValue: transactionProvider.selectedYear,
                    tooltip: 'Filter by Year',
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: transactionProvider.selectedYear != null
                              ? AppTheme.primaryColor
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: transactionProvider.selectedYear != null
                                ? AppTheme.primaryColor
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            transactionProvider.selectedYear != null
                                ? '${transactionProvider.selectedYear}'
                                : 'All Years',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: transactionProvider.selectedYear != null
                                  ? AppTheme.primaryColor
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 16),
                        ],
                      ),
                    ),
                    onSelected: (year) {
                      transactionProvider.setYearFilter(year);
                      _refreshData();
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem<int?>(
                          value: null,
                          child: Text('All Years'),
                        ),
                        ...transactionProvider.availableYears.map((y) {
                          return PopupMenuItem<int?>(
                            value: y,
                            child: Text('$y'),
                          );
                        }),
                      ];
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.sync_rounded,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    ),
                    tooltip: 'Sync SMS',
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Analyzing new SMS with Gemini AI...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      await transactionProvider.syncFromSMS(limit: 200);
                      if (mounted) _refreshData();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Date Range Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterChip(
                          context,
                          label: 'Today',
                          isSelected: transactionProvider.dateRangeType == DateRangeType.today,
                          onTap: () {
                            transactionProvider.setDateRange(DateRangeType.today);
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          context,
                          label: 'This Week',
                          isSelected: transactionProvider.dateRangeType == DateRangeType.week,
                          onTap: () {
                            transactionProvider.setDateRange(DateRangeType.week);
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          context,
                          label: 'This Month',
                          isSelected: transactionProvider.dateRangeType == DateRangeType.month,
                          onTap: () {
                            transactionProvider.setDateRange(DateRangeType.month);
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          context,
                          label: 'This Year',
                          isSelected: transactionProvider.dateRangeType == DateRangeType.year,
                          onTap: () {
                            transactionProvider.setDateRange(DateRangeType.year);
                            _refreshData();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          context,
                          label: 'All Time',
                          isSelected: transactionProvider.dateRangeType == DateRangeType.all,
                          onTap: () {
                            transactionProvider.setDateRange(DateRangeType.all);
                            _refreshData();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Hero Balance Card (iOS 18 Glass Card)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _buildHeroBalanceCard(context, analyticsProvider, isDark),
                ),
              ),

              // AI Waste of Money Alert Banner
              if (analyticsProvider.uselessSpends > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _buildWasteBanner(context, analyticsProvider, isDark),
                  ),
                ),

              // Top 3 Apps Quick Strip
              if (analyticsProvider.topApps.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _buildAppQuickStrip(context, analyticsProvider, transactionProvider, isDark),
                  ),
                ),

              // Recent Transactions Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _navigateToTab(2), // Jump to activity/transactions
                        child: Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Transactions List
              if (transactionProvider.filteredTransactions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions found for this period',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
                        final tx = transactionProvider.filteredTransactions.take(8).toList()[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TransactionCard(
                            transaction: tx,
                            // Clicking on a transaction directs to Activity (Tab 2) and filters to that transaction
                            onTap: () {
                              _navigateToTab(2);
                            },
                          ),
                        );
                      },
                      childCount: transactionProvider.filteredTransactions.take(8).length,
                    ),
                  ),
                ),

              // Floating action bar cushion
              const SliverToBoxAdapter(
                child: SizedBox(height: 110),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBalanceCard(
    BuildContext context,
    AnalyticsProvider provider,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1B4B),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFF4F46E5),
                  const Color(0xFF7C3AED),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(isDark ? 0.3 : 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -4,
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
                'NET SPENDABLE BALANCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'AI Verified',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(provider.balance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: Color(0xFF6EE7B7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Income',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(provider.totalIncome),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: Color(0xFFFCA5A5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spent',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.75),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(provider.totalExpense),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildWasteBanner(
    BuildContext context,
    AnalyticsProvider provider,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _navigateToTab(3), // Navigate to AI & Waste tab
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(isDark ? 0.3 : 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: Color(0xFFDC2626),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Waste of Money Detected',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${provider.uselessSpendPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${CurrencyFormatter.format(provider.uselessSpends)} in food delivery, shopping & impulses',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppQuickStrip(
    BuildContext context,
    AnalyticsProvider analyticsProvider,
    TransactionProvider transactionProvider,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'High Spending Apps',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
          ),
        ),
        Row(
          children: analyticsProvider.topApps.take(3).map((item) {
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  transactionProvider.setAppFilter(item.appName);
                  _navigateToTab(2); // Jump to activity filtered
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(item.totalAmount),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
