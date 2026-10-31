import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_card.dart';
import 'transactions_screen.dart';
import 'analytics_screen.dart';
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

    // Get date range based on current filter selection
    final dateRange = transactionProvider.getCurrentDateRange();
    final startDate = dateRange['start'];
    final endDate = dateRange['end'];

    // Filter transactions based on selected date range
    final rangeTransactions = startDate != null && endDate != null
        ? transactionProvider.allTransactions.where((t) {
            return t.dateTime.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                   t.dateTime.isBefore(endDate.add(const Duration(seconds: 1)));
          }).toList()
        : transactionProvider.allTransactions;

    // Update analytics with filtered transactions based on range
    analyticsProvider.updateAnalytics(rangeTransactions);

    // Get previous period for comparison based on current range
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

    // Update monthly trend with all transactions
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
      const AnalyticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionScreen(),
                  ),
                ).then((_) => _refreshData());
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Refresh data and clear TYPE/CATEGORY/BANK filters when returning to dashboard
          // but keep the DATE RANGE filter active so dashboard respects selected period
          if (index == 0) {
            final transactionProvider = context.read<TransactionProvider>();
            // Clear type, category, and bank filters but keep date range
            transactionProvider.setTypeFilter(null);
            transactionProvider.setCategoryFilter(null);
            transactionProvider.setBankFilter(null);
            _refreshData();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Consumer2<TransactionProvider, AnalyticsProvider>(
      builder: (context, transactionProvider, analyticsProvider, child) {
        // Show full-screen loader only on initial load (no data yet)
        if (transactionProvider.isLoading && transactionProvider.allTransactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await transactionProvider.syncFromSMS(limit: 200);
            if (mounted) _refreshData();
          },
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                title: const Text('FinTracker'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await transactionProvider.syncFromSMS(limit: 200);
                      if (mounted) _refreshData();
                    },
                  ),
                ],
              ),

              // Date Range Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildDateRangeSelector(transactionProvider),
                ),
              ),

              // Summary Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SummaryCard(
                              title: 'Income',
                              amount: CurrencyFormatter.formatCompact(analyticsProvider.totalIncome),
                              icon: Icons.arrow_downward,
                              color: AppTheme.incomeColor,
                              onTap: () {
                                transactionProvider.setTypeFilter(true); // Filter for Income (Credit)
                                setState(() {
                                  _selectedIndex = 1; // Navigate to Transactions tab
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SummaryCard(
                              title: 'Expense',
                              amount: CurrencyFormatter.formatCompact(analyticsProvider.totalExpense),
                              icon: Icons.arrow_upward,
                              color: AppTheme.expenseColor,
                              onTap: () {
                                transactionProvider.setTypeFilter(false); // Filter for Expense (Debit)
                                setState(() {
                                  _selectedIndex = 1; // Navigate to Transactions tab
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SummaryCard(
                              title: 'Balance',
                              amount: CurrencyFormatter.formatCompact(analyticsProvider.balance),
                              icon: Icons.account_balance_wallet,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SummaryCard(
                              title: 'Useless Spends',
                              amount: CurrencyFormatter.formatCompact(analyticsProvider.uselessSpends),
                              subtitle: '${analyticsProvider.uselessSpendPercentage.toStringAsFixed(0)}% of expenses',
                              icon: Icons.shopping_bag,
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Insights Section
              if (analyticsProvider.insights.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildInsightsCard(analyticsProvider.insights),
                  ),
                ),

              // Quick Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickStatCard(
                          'Biggest Expense',
                          analyticsProvider.biggestExpense != null
                              ? CurrencyFormatter.formatCompact(
                                  analyticsProvider.biggestExpense!.amount)
                              : '₹0',
                          analyticsProvider.biggestExpense?.category ?? '-',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickStatCard(
                          'Top Category',
                          analyticsProvider.topCategory ?? 'None',
                          analyticsProvider.topCategory != null
                              ? CurrencyFormatter.formatCompact(
                                  analyticsProvider.categoryBreakdown[
                                          analyticsProvider.topCategory] ??
                                      0)
                              : '₹0',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Transactions Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIndex = 1; // Navigate to transactions tab
                          });
                        },
                        child: const Text('View All'),
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
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No transactions found',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to add manually',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= 5) return null; // Show only 5 recent
                          final transaction =
                              transactionProvider.filteredTransactions[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            child: TransactionCard(transaction: transaction),
                          );
                        },
                        childCount: transactionProvider.filteredTransactions.length > 5
                            ? 5
                            : transactionProvider.filteredTransactions.length,
                      ),
                    ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateRangeSelector(TransactionProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildDateRangeChip(
            'Today',
            DateRangeType.today,
            provider.dateRangeType == DateRangeType.today,
            () {
              provider.setDateRange(DateRangeType.today);
              _refreshData();
            },
          ),
          const SizedBox(width: 8),
          _buildDateRangeChip(
            'Week',
            DateRangeType.week,
            provider.dateRangeType == DateRangeType.week,
            () {
              provider.setDateRange(DateRangeType.week);
              _refreshData();
            },
          ),
          const SizedBox(width: 8),
          _buildDateRangeChip(
            'Month',
            DateRangeType.month,
            provider.dateRangeType == DateRangeType.month,
            () {
              provider.setDateRange(DateRangeType.month);
              _refreshData();
            },
          ),
          const SizedBox(width: 8),
          _buildDateRangeChip(
            '6M',
            DateRangeType.sixMonths,
            provider.dateRangeType == DateRangeType.sixMonths,
            () {
              provider.setDateRange(DateRangeType.sixMonths);
              _refreshData();
            },
          ),
          const SizedBox(width: 8),
          _buildDateRangeChip(
            '1Y',
            DateRangeType.year,
            provider.dateRangeType == DateRangeType.year,
            () {
              provider.setDateRange(DateRangeType.year);
              _refreshData();
            },
          ),
          const SizedBox(width: 8),
          _buildDateRangeChip(
            'All',
            DateRangeType.all,
            provider.dateRangeType == DateRangeType.all,
            () {
              provider.setDateRange(DateRangeType.all);
              _refreshData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip(
    String label,
    DateRangeType type,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 80),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsCard(List<String> insights) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: AppTheme.warningColor),
                const SizedBox(width: 8),
                Text(
                  'Insights',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.take(3).map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    insight,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatCard(String title, String value, String subtitle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
