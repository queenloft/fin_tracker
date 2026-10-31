import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/models/otp_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/transaction_card.dart';

enum MainFilterTab { all, expenses, income, waste, otps }

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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Transactions & OTPs',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: -0.4,
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

          // Build filter counts
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _currentTab == MainFilterTab.otps
                          ? 'Search OTPs by service or code...'
                          : 'Search by merchant, app, amount, bank...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey[400]),
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

              // iOS 18 Segmented Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildSegmentTab(
                      tab: MainFilterTab.all,
                      label: 'All ($totalTxns)',
                      icon: Icons.list_rounded,
                      provider: provider,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.expenses,
                      label: 'Expenses',
                      icon: Icons.arrow_upward_rounded,
                      color: AppTheme.expenseColor,
                      provider: provider,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.income,
                      label: 'Income',
                      icon: Icons.arrow_downward_rounded,
                      color: AppTheme.incomeColor,
                      provider: provider,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.waste,
                      label: 'Waste of Money',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFFF5252),
                      provider: provider,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentTab(
                      tab: MainFilterTab.otps,
                      label: '🔐 OTPs ($totalOtps)',
                      icon: Icons.security_rounded,
                      color: const Color(0xFF6366F1),
                      provider: provider,
                    ),
                  ],
                ),
              ),

              // Secondary Quick Filters (Year, App, Bank)
              if (_currentTab != MainFilterTab.otps)
                _buildQuickFilterPills(provider),

              const SizedBox(height: 6),

              // Content List (Transactions or OTPs)
              Expanded(
                child: _currentTab == MainFilterTab.otps
                    ? _buildOtpList(provider)
                    : _buildTransactionList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegmentTab({
    required MainFilterTab tab,
    required String label,
    required IconData icon,
    Color? color,
    required TransactionProvider provider,
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
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.black.withOpacity(0.06),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.25),
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
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterPills(TransactionProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Year Filter Pill
          _buildPillDropdown<int>(
            label: provider.selectedYear != null ? 'Year: ${provider.selectedYear}' : 'Year: All',
            isSelected: provider.selectedYear != null,
            items: [null, ...provider.availableYears],
            itemLabel: (y) => y != null ? '$y' : 'All Years',
            onSelected: (y) => provider.setYearFilter(y),
          ),
          const SizedBox(width: 8),

          // App Filter Pill
          _buildPillDropdown<String>(
            label: provider.selectedApp != null ? 'App: ${provider.selectedApp}' : 'App: All',
            isSelected: provider.selectedApp != null,
            items: [null, ...provider.availableApps],
            itemLabel: (a) => a ?? 'All Apps',
            onSelected: (a) => provider.setAppFilter(a),
          ),
          const SizedBox(width: 8),

          // Bank Filter Pill
          _buildPillDropdown<String>(
            label: provider.selectedBank != null ? 'Bank: ${provider.selectedBank}' : 'Bank: All',
            isSelected: provider.selectedBank != null,
            items: [null, ...provider.availableBanks],
            itemLabel: (b) => b ?? 'All Banks',
            onSelected: (b) => provider.setBankFilter(b),
          ),

          if (provider.selectedYear != null ||
              provider.selectedApp != null ||
              provider.selectedBank != null ||
              provider.selectedCategory != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => provider.clearFilters(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Reset Filters',
                  style: TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.w600),
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
  }) {
    return PopupMenuButton<T?>(
      onSelected: onSelected,
      itemBuilder: (context) {
        return items.map((item) {
          return PopupMenuItem<T?>(
            value: item,
            child: Text(itemLabel(item)),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.black.withOpacity(0.08),
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
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(TransactionProvider provider) {
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
            Icon(Icons.inbox_outlined, size: 54, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No matching transactions found',
              style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your year, app, or bank filters',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
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

  Widget _buildOtpList(TransactionProvider provider) {
    var otps = provider.allOtps;

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
            Icon(Icons.security_rounded, size: 54, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No OTP messages found',
              style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Sync from SMS or wait for new incoming verification codes',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      itemCount: otps.length,
      itemBuilder: (context, index) {
        final otp = otps[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildOtpCard(context, otp),
        );
      },
    );
  }

  Widget _buildOtpCard(BuildContext context, OtpModel otp) {
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otp.serviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        otp.sender,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
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
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big OTP display + Copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'OTP: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      otp.code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: Color(0xFF111827),
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
                        backgroundColor: const Color(0xFF111827),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
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
              color: Colors.grey[600],
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

    showModalBottomSheet(
      context: context,
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
              const Text(
                'Filter Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Select Year'),
                trailing: Text(provider.selectedYear != null ? '${provider.selectedYear}' : 'All'),
                onTap: () {
                  Navigator.pop(ctx);
                  // pick year
                },
              ),
              ListTile(
                leading: const Icon(Icons.apps_rounded),
                title: const Text('Filter by App'),
                trailing: Text(provider.selectedApp ?? 'All'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance),
                title: const Text('Filter by Bank'),
                trailing: Text(provider.selectedBank ?? 'All'),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  provider.clearFilters();
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
