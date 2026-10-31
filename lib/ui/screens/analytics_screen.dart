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
  final ValueChanged<int>? onNavigateTab;

  const AnalyticsScreen({super.key, this.onNavigateTab});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _chartModeIndex = 0; // 0: Income vs Expense, 1: Category Breakdown, 2: Monthly Trends
  int? _touchedPieIndex;

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

    analyticsProvider.updateMonthlyTrend(
      transactionProvider.allTransactions,
      null,
    );
    analyticsProvider.setTimeRange(analyticsProvider.selectedTimeRange);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Consumer2<AnalyticsProvider, TransactionProvider>(
          builder: (context, provider, transactionProvider, child) {
            final breakdown = provider.categoryBreakdown;
            final trend = provider.monthlyTrend;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Visual Analytics',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Interactive chart breakdowns & financial metrics',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_graph_rounded,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Time Range Pills
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildTimeRangePill('1 Month', TimeRange.oneMonth, provider, isDark),
                          const SizedBox(width: 8),
                          _buildTimeRangePill('3 Months', TimeRange.threeMonths, provider, isDark),
                          const SizedBox(width: 8),
                          _buildTimeRangePill('6 Months', TimeRange.sixMonths, provider, isDark),
                          const SizedBox(width: 8),
                          _buildTimeRangePill('1 Year', TimeRange.oneYear, provider, isDark),
                          const SizedBox(width: 8),
                          _buildTimeRangePill('All Time', TimeRange.all, provider, isDark),
                        ],
                      ),
                    ),
                  ),
                ),

                // Financial Overview Highlight Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: _buildSummaryMetricsCard(provider, isDark),
                  ),
                ),

                // Segmented Switcher for Charts
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildSegmentItem('Trend Graph', 0, isDark),
                          _buildSegmentItem('Categories', 1, isDark),
                          _buildSegmentItem('Cashflow Bar', 2, isDark),
                        ],
                      ),
                    ),
                  ),
                ),

                // Main Selected Chart Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: _buildSelectedChartCard(provider, isDark, breakdown, trend),
                  ),
                ),

                // Spend by Top Apps / Merchants
                if (provider.topApps.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: _buildTopAppsCard(provider, isDark),
                    ),
                  ),

                // Bank Breakdown
                if (provider.bankBreakdown.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: _buildBankBreakdownCard(provider, isDark),
                    ),
                  ),

                // Category Leaderboard
                if (breakdown.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: _buildCategoryLeaderboard(breakdown, provider.totalExpense, isDark),
                    ),
                  ),

                // Bottom padding for iOS 18 floating bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 110),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeRangePill(
    String label,
    TimeRange range,
    AnalyticsProvider provider,
    bool isDark,
  ) {
    final isSelected = provider.selectedTimeRange == range;
    return GestureDetector(
      onTap: () => provider.setTimeRange(range),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetricsCard(AnalyticsProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Period Net Flow',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: provider.balance >= 0
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : const Color(0xFFEF4444).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  provider.balance >= 0 ? '+ Savings' : '- Deficit',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: provider.balance >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(provider.balance),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricPill(
                  title: 'Income',
                  amount: provider.totalIncome,
                  color: const Color(0xFF10B981),
                  icon: Icons.arrow_downward_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricPill(
                  title: 'Expense',
                  amount: provider.totalExpense,
                  color: const Color(0xFFEF4444),
                  icon: Icons.arrow_upward_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(amount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String title, int index, bool isDark) {
    final isSelected = _chartModeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _chartModeIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF334155) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChartCard(
    AnalyticsProvider provider,
    bool isDark,
    Map<String, double> breakdown,
    List<MonthlyData> trend,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_chartModeIndex == 0) ...[
            _buildChartHeader('Spending & Income Flow Line', 'Monthly trajectory analysis', isDark),
            const SizedBox(height: 20),
            _buildLineChart(trend, isDark),
          ] else if (_chartModeIndex == 1) ...[
            _buildChartHeader('Expense Distribution', 'Share by spending category', isDark),
            const SizedBox(height: 16),
            _buildDonutChart(breakdown, isDark),
          ] else ...[
            _buildChartHeader('Monthly Cashflow Bars', 'Income (Green) vs Expenses (Red)', isDark),
            const SizedBox(height: 20),
            _buildBarChart(trend, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildChartHeader(String title, String subtitle, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(List<MonthlyData> trend, bool isDark) {
    if (trend.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No transaction history available')),
      );
    }

    final expenseSpots = <FlSpot>[];
    final incomeSpots = <FlSpot>[];
    double maxY = 1000;

    for (int i = 0; i < trend.length; i++) {
      final e = trend[i].expense;
      final inc = trend[i].income;
      if (e > maxY) maxY = e;
      if (inc > maxY) maxY = inc;
      expenseSpots.add(FlSpot(i.toDouble(), e));
      incomeSpots.add(FlSpot(i.toDouble(), inc));
    }
    maxY *= 1.25;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildLegendBadge('Income', const Color(0xFF10B981)),
            const SizedBox(width: 14),
            _buildLegendBadge('Expense', const Color(0xFFEF4444)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              maxY: maxY,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 1000,
                getDrawingHorizontalLine: (val) => FlLine(
                  color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      String text;
                      if (value >= 100000) {
                        text = '${(value / 100000).toStringAsFixed(0)}L';
                      } else if (value >= 1000) {
                        text = '${(value / 1000).toStringAsFixed(0)}k';
                      } else {
                        text = value.toStringAsFixed(0);
                      }
                      return Text(
                        '₹$text',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          trend[idx].monthName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                // Income Line
                LineChartBarData(
                  spots: incomeSpots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: const Color(0xFF10B981),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF10B981),
                        strokeWidth: 2,
                        strokeColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF10B981).withOpacity(0.08),
                  ),
                ),
                // Expense Line
                LineChartBarData(
                  spots: expenseSpots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: const Color(0xFFEF4444),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFFEF4444),
                        strokeWidth: 2,
                        strokeColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonutChart(Map<String, double> breakdown, bool isDark) {
    if (breakdown.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No expense categories to show')),
      );
    }

    final total = breakdown.values.fold<double>(0, (sum, val) => sum + val);
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = sortedEntries.asMap().entries.map((entryMap) {
      final idx = entryMap.key;
      final entry = entryMap.value;
      final isTouched = idx == _touchedPieIndex;
      final color = AppConstants.categoryColors[entry.key] ?? Colors.indigo;
      final percent = total > 0 ? (entry.value / total) * 100 : 0.0;

      return PieChartSectionData(
        value: entry.value,
        color: color,
        radius: isTouched ? 48 : 40,
        showTitle: isTouched,
        title: '${percent.toStringAsFixed(0)}%',
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedPieIndex = null;
                          return;
                        }
                        _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: sections,
                  centerSpaceRadius: 55,
                  sectionsSpace: 3,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(total),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: sortedEntries.take(6).map((e) {
            final color = AppConstants.categoryColors[e.key] ?? Colors.indigo;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  e.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<MonthlyData> trend, bool isDark) {
    if (trend.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No data available')),
      );
    }

    double maxY = 1000;
    for (var m in trend) {
      if (m.expense > maxY) maxY = m.expense;
      if (m.income > maxY) maxY = m.income;
    }
    maxY *= 1.25;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildLegendBadge('Income', const Color(0xFF10B981)),
            const SizedBox(width: 14),
            _buildLegendBadge('Expense', const Color(0xFFEF4444)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 1000,
                getDrawingHorizontalLine: (val) => FlLine(
                  color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      String text;
                      if (value >= 100000) {
                        text = '${(value / 100000).toStringAsFixed(0)}L';
                      } else if (value >= 1000) {
                        text = '${(value / 1000).toStringAsFixed(0)}k';
                      } else {
                        text = value.toStringAsFixed(0);
                      }
                      return Text(
                        '₹$text',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          trend[idx].monthName,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: trend.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.income,
                      color: const Color(0xFF10B981),
                      width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: entry.value.expense,
                      color: const Color(0xFFEF4444),
                      width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                  barsSpace: 4,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendBadge(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildTopAppsCard(AnalyticsProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Merchant Platforms',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Icon(Icons.storefront_rounded, size: 20, color: AppTheme.primaryColor),
            ],
          ),
          const SizedBox(height: 14),
          ...provider.topApps.take(5).map((app) {
            final percent = provider.totalExpense > 0
                ? (app.totalAmount / provider.totalExpense)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            app.appName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${app.count} txns',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(app.totalAmount),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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

  Widget _buildBankBreakdownCard(AnalyticsProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Institution Share',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Icon(Icons.account_balance_rounded, size: 20, color: AppTheme.secondaryColor),
            ],
          ),
          const SizedBox(height: 14),
          ...provider.bankBreakdown.entries.take(5).map((entry) {
            final bank = entry.key;
            final expense = entry.value['expense'] ?? 0.0;
            final income = entry.value['income'] ?? 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_outlined, size: 16, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        bank,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (expense > 0)
                        Text(
                          '-${CurrencyFormatter.format(expense)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      if (income > 0)
                        Text(
                          '+${CurrencyFormatter.format(income)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryLeaderboard(
    Map<String, double> breakdown,
    double totalExpense,
    bool isDark,
  ) {
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Leaderboard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          ...sorted.map((item) {
            final color = AppConstants.categoryColors[item.key] ?? Colors.indigo;
            final percent = totalExpense > 0 ? (item.value / totalExpense) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.key,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${CurrencyFormatter.format(item.value)}  (${(percent * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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
}
