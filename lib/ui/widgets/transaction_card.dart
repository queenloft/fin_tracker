import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/transaction_model.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_utils.dart' as app_date_utils;

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryIcon = AppConstants.categoryIcons[transaction.category] ?? Icons.category_rounded;
    final categoryColor = AppConstants.categoryColors[transaction.category] ?? const Color(0xFF6366F1);
    final isWaste = transaction.isUselessSpend() && !transaction.isCredit;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap ?? () => _showDetails(context, isDark),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Category / App Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    categoryIcon,
                    color: categoryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Description, Category & Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              transaction.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                letterSpacing: -0.2,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (isWaste) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Waste',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            transaction.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          if (transaction.bankName.isNotEmpty && transaction.bankName != 'Unknown') ...[
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            Text(
                              transaction.bankName,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Amount & Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      transaction.isCredit
                          ? '+${CurrencyFormatter.format(transaction.amount)}'
                          : '-${CurrencyFormatter.format(transaction.amount)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: transaction.isCredit
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app_date_utils.DateUtils.formatRelativeDate(transaction.dateTime),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (AppConstants.categoryColors[transaction.category] ?? Colors.grey)
                          .withOpacity(isDark ? 0.25 : 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      AppConstants.categoryIcons[transaction.category] ?? Icons.category_rounded,
                      color: AppConstants.categoryColors[transaction.category] ?? Colors.grey,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    transaction.isCredit
                        ? '+${CurrencyFormatter.format(transaction.amount)}'
                        : '-${CurrencyFormatter.format(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: transaction.isCredit
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.description,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            _buildDetailRow('Category', transaction.category, isDark),
            _buildDetailRow('Date & Time', app_date_utils.DateUtils.formatDateTime(transaction.dateTime), isDark),
            _buildDetailRow('Bank / Channel', transaction.bankName, isDark),
            _buildDetailRow('Type', transaction.isCredit ? 'Income (Credit)' : 'Expense (Debit)', isDark),
            if (transaction.isUselessSpend())
              _buildDetailRow('Classification', 'Discretionary / Waste of Money', isDark, isAlert: true),
            const SizedBox(height: 16),
            Text(
              'RAW SMS BODY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
                ),
              ),
              child: Text(
                transaction.rawSms,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFCBD5E1) : Colors.grey[700],
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isAlert
                  ? const Color(0xFFEF4444)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
