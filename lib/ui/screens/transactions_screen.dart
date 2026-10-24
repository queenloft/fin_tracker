import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/transaction_card.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Apply search filter on top of existing filters
          final searchFilteredTransactions = _searchQuery.isEmpty
              ? provider.filteredTransactions
              : provider.filteredTransactions.where((t) {
                  final query = _searchQuery.toLowerCase();
                  return t.description.toLowerCase().contains(query) ||
                         t.bankName.toLowerCase().contains(query) ||
                         t.category.toLowerCase().contains(query) ||
                         t.rawSms.toLowerCase().contains(query) ||
                         t.amount.toString().contains(query);
                }).toList();

          return Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),

              // Active Filters Display
              if (provider.selectedType != null || 
                  provider.selectedCategory != null || 
                  provider.selectedBank != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blue[50],
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (provider.selectedType != null)
                        Chip(
                          label: Text(provider.selectedType! ? 'Income' : 'Expense'),
                          onDeleted: () => provider.setTypeFilter(null),
                          deleteIconColor: Colors.blue[700],
                          backgroundColor: Colors.blue[100],
                        ),
                      if (provider.selectedBank != null)
                        Chip(
                          label: Text(provider.selectedBank!),
                          onDeleted: () => provider.setBankFilter(null),
                          deleteIconColor: Colors.green[700],
                          backgroundColor: Colors.green[100],
                        ),
                      if (provider.selectedCategory != null)
                        Chip(
                          label: Text(provider.selectedCategory!),
                          onDeleted: () => provider.setCategoryFilter(null),
                          deleteIconColor: Colors.orange[700],
                          backgroundColor: Colors.orange[100],
                        ),
                    ],
                  ),
                ),
              ],

              // Results Summary Bar
              if (searchFilteredTransactions.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Builder(
                    builder: (context) {
                      final totalIncome = searchFilteredTransactions
                          .where((t) => t.isCredit)
                          .fold<double>(0, (sum, t) => sum + t.amount);
                      final totalExpense = searchFilteredTransactions
                          .where((t) => !t.isCredit)
                          .fold<double>(0, (sum, t) => sum + t.amount);
                      final balance = totalIncome - totalExpense;

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${searchFilteredTransactions.length} transaction${searchFilteredTransactions.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildSummaryItem('Income', totalIncome, Colors.green),
                                    const SizedBox(width: 16),
                                    _buildSummaryItem('Expense', totalExpense, Colors.red),
                                    const SizedBox(width: 16),
                                    _buildSummaryItem('Balance', balance, balance >= 0 ? Colors.blue : Colors.red),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              // Transactions List
              Expanded(
                child: searchFilteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No transactions match your search'
                                  : 'No transactions found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: searchFilteredTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = searchFilteredTransactions[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: TransactionCard(transaction: transaction),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        Text(
          '₹${(amount / 1000).toStringAsFixed(1)}K',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showFilterDialog(BuildContext context) {
    final provider = context.read<TransactionProvider>();

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Type filter
            Text('Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: provider.selectedType == null,
                  onSelected: (_) {
                    provider.setTypeFilter(null);
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Income'),
                  selected: provider.selectedType == true,
                  onSelected: (_) {
                    provider.setTypeFilter(true);
                    Navigator.pop(context);
                  },
                ),
                FilterChip(
                  label: const Text('Expense'),
                  selected: provider.selectedType == false,
                  onSelected: (_) {
                    provider.setTypeFilter(false);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bank filter
            if (provider.availableBanks.isNotEmpty) ...[
              Text('Bank', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: provider.selectedBank == null,
                    onSelected: (_) {
                      provider.setBankFilter(null);
                      Navigator.pop(context);
                    },
                  ),
                  ...provider.availableBanks.map((bank) {
                    return FilterChip(
                      label: Text(bank),
                      selected: provider.selectedBank == bank,
                      onSelected: (_) {
                        provider.setBankFilter(bank);
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Category filter
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: provider.selectedCategory == null,
                  onSelected: (_) {
                    provider.setCategoryFilter(null);
                    Navigator.pop(context);
                  },
                ),
                ...AppConstants.allCategories.take(5).map((category) {
                  return FilterChip(
                    label: Text(category),
                    selected: provider.selectedCategory == category,
                    onSelected: (_) {
                      provider.setCategoryFilter(category);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            
            // Clear filters
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  provider.clearFilters();
                  Navigator.pop(context);
                },
                child: const Text('Clear All Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
