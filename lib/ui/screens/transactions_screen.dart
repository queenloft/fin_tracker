import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/models/otp_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/transaction_card.dart';

enum MainFilterTab { all, expenses, income, waste, senders, otps }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MainFilterTab _currentTab = MainFilterTab.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Transactions & Intelligence',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter Options',
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final totalTxns = provider.allTransactions.length;
          final totalOtps = provider.allOtps.length;

          return Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: _currentTab == MainFilterTab.otps
                          ? 'Search OTPs by service or code...'
                          : (_currentTab == MainFilterTab.senders
                              ? 'Search payees or senders...'
                              : 'Search by merchant, amount, bank...'),
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
              ),

              // Segmented Tab Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildSegmentTab(
                      tab: MainFilterTab.all,
                      label: 'All ($totalTxns)',
                      icon: Icons.list_rounded,
                      provider: provider,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.expenses,
                      label: 'Expenses',
                      icon: Icons.arrow_upward_rounded,
                      color: AppTheme.expenseColor,
                      provider: provider,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.income,
                      label: 'Income',
                      icon: Icons.arrow_downward_rounded,
                      color: AppTheme.incomeColor,
                      provider: provider,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.waste,
                      label: 'Waste Spends',
                      icon: Icons.delete_sweep_rounded,
                      color: const Color(0xFFEF4444),
                      provider: provider,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.senders,
                      label: 'Top Payees',
                      icon: Icons.person_search_rounded,
                      color: const Color(0xFF8B5CF6),
                      provider: provider,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.otps,
                      label: '🔐 OTPs ($totalOtps)',
                      icon: Icons.security_rounded,
                      color: const Color(0xFF6366F1),
                      provider: provider,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              // Quick Filter Pills (Year, App, Bank, Payee) OR OTP Filters
              if (_currentTab == MainFilterTab.otps)
                _buildOtpQuickFilterPills(provider, isDark)
              else if (_currentTab != MainFilterTab.senders)
                _buildQuickFilterPills(provider, isDark),

              // Sum of all amounts dynamic card
              if (_currentTab != MainFilterTab.senders && _currentTab != MainFilterTab.otps)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: _buildFilterSumCard(provider, isDark),
                ),

              // OTP Filter count banner
              if (_currentTab == MainFilterTab.otps && provider.hasActiveOtpFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: _buildOtpFilterSummaryCard(provider, isDark),
                ),

              const SizedBox(height: 4),

              // Content List
              Expanded(
                child: _buildCurrentContent(provider, isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentContent(TransactionProvider provider, bool isDark) {
    if (_currentTab == MainFilterTab.otps) {
      return _buildOtpList(provider, isDark);
    } else if (_currentTab == MainFilterTab.senders) {
      return _buildTopPayeesList(provider, isDark);
    } else {
      return _buildTransactionList(provider, isDark);
    }
  }

  Widget _buildSegmentTab({
    required MainFilterTab tab,
    required String label,
    required IconData icon,
    Color? color,
    required TransactionProvider provider,
    required bool isDark,
  }) {
    final isSelected = _currentTab == tab;
    final activeColor = color ?? AppTheme.primaryColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _currentTab = tab;
        });

        if (tab == MainFilterTab.all) {
          provider.setTypeFilter(null);
          provider.setOnlyWastedFilter(false);
        } else if (tab == MainFilterTab.expenses) {
          provider.setTypeFilter(false);
          provider.setOnlyWastedFilter(false);
        } else if (tab == MainFilterTab.income) {
          provider.setTypeFilter(true);
          provider.setOnlyWastedFilter(false);
        } else if (tab == MainFilterTab.waste) {
          provider.setTypeFilter(false);
          provider.setOnlyWastedFilter(true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sum of all filtered amounts card
  Widget _buildFilterSumCard(TransactionProvider provider, bool isDark) {
    final count = provider.filteredTransactionCount;
    final totalExpense = provider.filteredExpenseSum;
    final totalIncome = provider.filteredIncomeSum;
    final net = provider.filteredNetBalance;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'FILTER SUMMARY',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count txns',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                CurrencyFormatter.format(provider.filteredTotalAmount),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (totalIncome > 0)
                _buildSmallSummaryTag('+$totalIncome', const Color(0xFF10B981), isDark),
              if (totalIncome > 0 && totalExpense > 0) const SizedBox(width: 8),
              if (totalExpense > 0)
                _buildSmallSummaryTag('-$totalExpense', const Color(0xFFEF4444), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallSummaryTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildOtpFilterSummaryCard(TransactionProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                'Showing ${provider.filteredOtps.length} filtered OTP codes',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => provider.clearOtpFilters(),
            child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterPills(TransactionProvider provider, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Year Filter
          _buildPillDropdown<int>(
            label: provider.selectedYear != null ? 'Year: ${provider.selectedYear}' : 'Year: All',
            isSelected: provider.selectedYear != null,
            items: [null, ...provider.availableYears],
            itemLabel: (y) => y != null ? '$y' : 'All Years',
            onSelected: (y) => provider.setYearFilter(y),
            isDark: isDark,
          ),
          const SizedBox(width: 8),

          // App Filter (Recognized Consumer Apps only)
          _buildPillDropdown<String>(
            label: provider.selectedApp != null ? 'App: ${provider.selectedApp}' : 'Apps',
            isSelected: provider.selectedApp != null,
            items: [null, ...provider.availableApps],
            itemLabel: (a) => a ?? 'All Recognized Apps',
            onSelected: (a) => provider.setAppFilter(a),
            isDark: isDark,
          ),
          const SizedBox(width: 8),

          // Payee Filter (Most paid to)
          _buildPillDropdown<String>(
            label: provider.selectedPayee != null ? 'Payee: ${provider.selectedPayee}' : 'Paid To',
            isSelected: provider.selectedPayee != null,
            items: [null, ...provider.availablePayees],
            itemLabel: (p) => p ?? 'All Payees',
            onSelected: (p) => provider.setPayeeFilter(p),
            isDark: isDark,
          ),
          const SizedBox(width: 8),

          // Bank Filter
          _buildPillDropdown<String>(
            label: provider.selectedBank != null ? 'Bank: ${provider.selectedBank}' : 'Bank',
            isSelected: provider.selectedBank != null,
            items: [null, ...provider.availableBanks],
            itemLabel: (b) => b ?? 'All Banks',
            onSelected: (b) => provider.setBankFilter(b),
            isDark: isDark,
          ),

          if (provider.hasActiveFilters) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => provider.clearFilters(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Reset Filters',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpQuickFilterPills(TransactionProvider provider, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildPillDropdown<String>(
            label: provider.selectedOtpService != null
                ? 'Service: ${provider.selectedOtpService}'
                : 'Service: All',
            isSelected: provider.selectedOtpService != null,
            items: [null, ...provider.availableOtpServices],
            itemLabel: (s) => s ?? 'All Services',
            onSelected: (s) => provider.setOtpServiceFilter(s),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildPillDropdown<String>(
            label: provider.selectedOtpSender != null
                ? 'Sender: ${provider.selectedOtpSender}'
                : 'Sender: All',
            isSelected: provider.selectedOtpSender != null,
            items: [null, ...provider.availableOtpSenders],
            itemLabel: (s) => s ?? 'All Senders',
            onSelected: (s) => provider.setOtpSenderFilter(s),
            isDark: isDark,
          ),
          if (provider.hasActiveOtpFilters) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => provider.clearOtpFilters(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPillDropdown<T>({
    required String label,
    required bool isSelected,
    required List<T?> items,
    required String Function(T?) itemLabel,
    required ValueChanged<T?> onSelected,
    required bool isDark,
  }) {
    return PopupMenuButton<T?>(
      onSelected: onSelected,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) {
        return items.map((item) {
          return PopupMenuItem<T?>(
            value: item,
            child: Text(
              itemLabel(item),
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.15)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(TransactionProvider provider, bool isDark) {
    var list = provider.filteredTransactions;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        return t.description.toLowerCase().contains(q) ||
            t.bankName.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            t.rawSms.toLowerCase().contains(q) ||
            t.amount.toString().contains(q);
      }).toList();
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 54, color: isDark ? const Color(0xFF475569) : Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No matching transactions found',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your year, app, or payee filters',
              style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final txn = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TransactionCard(transaction: txn),
        );
      },
    );
  }

  // Top Payees / Senders List
  Widget _buildTopPayeesList(TransactionProvider provider, bool isDark) {
    var senders = provider.topPaidSenders;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      senders = senders.where((s) => s.name.toLowerCase().contains(q)).toList();
    }

    if (senders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_outlined, size: 54, color: isDark ? const Color(0xFF475569) : Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No payee history available',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      itemCount: senders.length,
      itemBuilder: (context, index) {
        final payee = senders[index];
        final isSelected = provider.selectedPayee == payee.name;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              provider.setPayeeFilter(payee.name);
              setState(() {
                _currentTab = MainFilterTab.all;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        payee.name.isNotEmpty ? payee.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payee.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${payee.count} transactions • ${payee.percentage.toStringAsFixed(1)}% of total spends',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(payee.totalAmount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tap to filter',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOtpList(TransactionProvider provider, bool isDark) {
    var otps = provider.filteredOtps;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      otps = otps.where((o) {
        return o.serviceName.toLowerCase().contains(q) ||
            o.sender.toLowerCase().contains(q) ||
            o.code.contains(q) ||
            o.body.toLowerCase().contains(q);
      }).toList();
    }

    if (otps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security_rounded, size: 54, color: isDark ? const Color(0xFF475569) : Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No OTP messages found',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sync from SMS or wait for new incoming verification codes',
              style: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      itemCount: otps.length,
      itemBuilder: (context, index) {
        final otp = otps[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildOtpCard(context, otp, isDark),
        );
      },
    );
  }

  Widget _buildOtpCard(BuildContext context, OtpModel otp, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.02),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_rounded, size: 16, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otp.serviceName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        otp.sender,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                _formatRelativeTime(otp.dateTime),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Monospace OTP digits + One-tap Copy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'OTP: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      otp.code,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: otp.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied OTP: ${otp.code}'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Text(
            otp.body,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showFilterBottomSheet(BuildContext context) {
    final provider = context.read<TransactionProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.person_search, color: AppTheme.secondaryColor),
                title: const Text('Filter by Payee'),
                trailing: Text(provider.selectedPayee ?? 'All'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.apps_rounded, color: AppTheme.primaryColor),
                title: const Text('Filter by Recognized App'),
                trailing: Text(provider.selectedApp ?? 'All'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance, color: Colors.blue),
                title: const Text('Filter by Bank'),
                trailing: Text(provider.selectedBank ?? 'All'),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  provider.clearFilters();
                  provider.clearOtpFilters();
                  Navigator.pop(ctx);
                },
                child: const Text('Clear All Filters'),
              ),
            ],
          ),
        );
      },
    );
  }
}
