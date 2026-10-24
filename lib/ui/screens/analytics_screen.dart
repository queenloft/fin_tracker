import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/analytics_service.dart';
import '../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAnalytics();
    });
  }

  void _refreshAnalytics() {
    if (!mounted) return;
    
    final transactionProvider = context.read<TransactionProvider>();
    final analyticsProvider = context.read<AnalyticsProvider>();

    // Store all transactions for trend analysis
    analyticsProvider.updateMonthlyTrend(
      transactionProvider.allTransactions,
      null,
    );

    // Trigger the time range filter which will update all metrics
    // This ensures pie chart and other metrics match the selected range
    analyticsProvider.setTimeRange(analyticsProvider.selectedTimeRange);

    // Get current month's transactions for comparison insights
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    
    final currentMonthTransactions = transactionProvider.allTransactions.where((t) {
      return t.dateTime.isAfter(startOfMonth) && t.dateTime.isBefore(endOfMonth);
    }).toList();

    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final previousMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
    
    final previousMonthTransactions = transactionProvider.allTransactions.where((t) {
      return t.dateTime.isAfter(previousMonthStart) && t.dateTime.isBefore(previousMonthEnd);
    }).toList();

    analyticsProvider.updateWithComparison(
      currentMonthTransactions,
      previousMonthTransactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Range Selector at the top
                _buildSectionTitle(context, 'Time Range'),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTimeRangeChip(context, provider, '1M', TimeRange.oneMonth),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(context, provider, '3M', TimeRange.threeMonths),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(context, provider, '6M', TimeRange.sixMonths),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(context, provider, '1Y', TimeRange.oneYear),
                      const SizedBox(width: 8),
                      _buildTimeRangeChip(context, provider, 'All', TimeRange.all),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Category Breakdown Pie Chart
                _buildSectionTitle(context, 'Spending by Category'),
                const SizedBox(height: 52),
                _buildPieChart(provider.categoryBreakdown),
                const SizedBox(height: 32),

                // Monthly Trend Bar Chart
                _buildSectionTitle(context, 'Income & Expense Trend'),
                const SizedBox(height: 16),
                _buildBarChart(provider.monthlyTrend),
                const SizedBox(height: 32),

                // Insights
                if (provider.insights.isNotEmpty) ...[
                  _buildSectionTitle(context, 'Insights'),
                  const SizedBox(height: 16),
                  ...provider.insights.map((insight) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(insight),
                          ),
                        ),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _buildPieChart(Map<String, double> breakdown) {
    if (breakdown.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No data available')),
      );
    }

    final sections = breakdown.entries.map((entry) {
      final color = AppConstants.categoryColors[entry.key] ?? Colors.grey;
      return PieChartSectionData(
        value: entry.value,
        title: '${((entry.value / breakdown.values.reduce((a, b) => a + b)) * 100).toStringAsFixed(0)}%',
        color: color,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 52),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: breakdown.entries.map((entry) {
            final color = AppConstants.categoryColors[entry.key] ?? Colors.grey;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text('${entry.key}: ${CurrencyFormatter.format(entry.value)}'),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<MonthlyData> trend) {
    if (trend.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No data available')),
      );
    }

    // Calculate max value for chart scaling
    final maxExpense = trend.map((e) => e.expense).reduce((a, b) => a > b ? a : b);
    final maxIncome = trend.map((e) => e.income).reduce((a, b) => a > b ? a : b);
    final maxY = (maxExpense > maxIncome ? maxExpense : maxIncome) * 1.2;

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Income', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(width: 24),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Expense', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barGroups: trend.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    // Income bar (green)
                    BarChartRodData(
                      toY: entry.value.income,
                      color: Colors.green,
                      width: 12,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    // Expense bar (red)
                    BarChartRodData(
                      toY: entry.value.expense,
                      color: Colors.red,
                      width: 12,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                  barsSpace: 4,
                );
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text('');
                      // Format with K for thousands
                      String formatted;
                      if (value >= 100000) {
                        formatted = '${(value / 100000).toStringAsFixed(0)}L';
                      } else if (value >= 1000) {
                        formatted = '${(value / 1000).toStringAsFixed(0)}K';
                      } else {
                        formatted = value.toStringAsFixed(0);
                      }
                      return Text(
                        '₹$formatted',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= trend.length) return const Text('');
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          trend[value.toInt()].monthName,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[300],
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Colors.grey[300]!),
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeChip(
    BuildContext context,
    AnalyticsProvider provider,
    String label,
    TimeRange range,
  ) {
    final isSelected = provider.selectedTimeRange == range;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          provider.setTimeRange(range);
        }
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
