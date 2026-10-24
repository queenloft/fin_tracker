import 'package:flutter/material.dart';
import '../../data/models/transaction_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart' as app_date_utils;

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionCard({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final categoryIcon = AppConstants.categoryIcons[transaction.category] ?? Icons.more_horiz;
    final categoryColor = AppConstants.categoryColors[transaction.category] ?? Colors.grey;

    return Card(
      child: InkWell(
        onTap: () => _showDetails(context),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: categoryColor.withOpacity(0.2),
            child: Icon(
              categoryIcon,
              color: categoryColor,
            ),
          ),
          title: Text(
            transaction.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${transaction.category} • ${app_date_utils.DateUtils.formatRelativeDate(transaction.dateTime)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Text(
            transaction.isCredit
                ? '+${CurrencyFormatter.formatCompact(transaction.amount)}'
                : '-${CurrencyFormatter.formatCompact(transaction.amount)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: transaction.isCredit ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: (AppConstants.categoryColors[transaction.category] ?? Colors.grey).withOpacity(0.2),
                      child: Icon(
                        AppConstants.categoryIcons[transaction.category] ?? Icons.more_horiz,
                        color: AppConstants.categoryColors[transaction.category] ?? Colors.grey,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      transaction.isCredit
                          ? '+${CurrencyFormatter.formatCompact(transaction.amount)}'
                          : '-${CurrencyFormatter.formatCompact(transaction.amount)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: transaction.isCredit ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      transaction.description,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildDetailRow(context, 'Category', transaction.category),
              _buildDetailRow(context, 'Date', app_date_utils.DateUtils.formatDate(transaction.dateTime)),
              _buildDetailRow(context, 'Bank', transaction.bankName),
              if (transaction.rawSms.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Original SMS',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    transaction.rawSms,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: Colors.black87,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
