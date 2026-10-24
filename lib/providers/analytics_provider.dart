import 'package:flutter/foundation.dart';
import '../data/models/transaction_model.dart';
import '../services/analytics_service.dart';
import '../core/utils/date_utils.dart' as app_date_utils;

class AnalyticsProvider with ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();

  List<TransactionModel> _currentTransactions = [];
  List<TransactionModel> _previousTransactions = [];

  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _balance = 0.0;
  double _uselessSpends = 0.0;
  double _uselessSpendPercentage = 0.0;
  
  Map<String, double> _categoryBreakdown = {};
  TransactionModel? _biggestExpense;
  String? _topCategory;
  List<String> _insights = [];
  List<MonthlyData> _monthlyTrend = [];

  // Getters
  double get totalIncome => _totalIncome;
  double get totalExpense => _totalExpense;
  double get balance => _balance;
  double get uselessSpends => _uselessSpends;
  double get uselessSpendPercentage => _uselessSpendPercentage;
  Map<String, double> get categoryBreakdown => _categoryBreakdown;
  TransactionModel? get biggestExpense => _biggestExpense;
  String? get topCategory => _topCategory;
  List<String> get insights => _insights;
  List<MonthlyData> get monthlyTrend => _monthlyTrend;

  // Update analytics with current transactions
  void updateAnalytics(List<TransactionModel> transactions) {
    _currentTransactions = transactions;
    _calculateMetrics();
    notifyListeners();
  }

  // Update with previous period for comparison
  void updateWithComparison(
    List<TransactionModel> current,
    List<TransactionModel> previous,
  ) {
    _currentTransactions = current;
    _previousTransactions = previous;
    _calculateMetrics();
    _generateInsights();
    notifyListeners();
  }

  // Calculate all metrics
  void _calculateMetrics() {
    _totalIncome = _analyticsService.getTotalIncome(_currentTransactions);
    _totalExpense = _analyticsService.getTotalExpense(_currentTransactions);
    _balance = _analyticsService.getBalance(_currentTransactions);
    _uselessSpends = _analyticsService.getUselessSpends(_currentTransactions);
    _uselessSpendPercentage = _analyticsService.getUselessSpendPercentage(_currentTransactions);
    _categoryBreakdown = _analyticsService.getCategoryBreakdown(_currentTransactions);
    _biggestExpense = _analyticsService.getBiggestExpense(_currentTransactions);
    _topCategory = _analyticsService.getTopSpendingCategory(_currentTransactions);
  }

  // Generate insights
  void _generateInsights() {
    _insights = _analyticsService.generateInsights(
      _currentTransactions,
      _previousTransactions,
    );
  }

  List<TransactionModel> _trendTransactions = [];

  // Update monthly trend
  void updateMonthlyTrend(List<TransactionModel> allTransactions, int? months) {
    _trendTransactions = allTransactions;
    final monthsToLoad = months ?? getMonthsForRange(_selectedTimeRange, allTransactions);
    _monthlyTrend = _analyticsService.getSpendingTrend(allTransactions, monthsToLoad);
    notifyListeners();
  }

  // Time Range Logic
  TimeRange _selectedTimeRange = TimeRange.sixMonths;
  TimeRange get selectedTimeRange => _selectedTimeRange;

  void setTimeRange(TimeRange range) {
    _selectedTimeRange = range;
    final months = getMonthsForRange(range, _trendTransactions);
    
    // Update monthly trend
    _monthlyTrend = _analyticsService.getSpendingTrend(_trendTransactions, months);
    
    // Filter transactions based on selected time range
    final now = DateTime.now();
    DateTime startDate;
    
    switch (range) {
      case TimeRange.oneMonth:
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case TimeRange.threeMonths:
        startDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case TimeRange.sixMonths:
        startDate = DateTime(now.year, now.month - 6, now.day);
        break;
      case TimeRange.oneYear:
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      case TimeRange.all:
        startDate = DateTime(2000, 1, 1); // Very old date to include all
        break;
    }
    
    // Filter transactions for the selected range
    final filteredTransactions = _trendTransactions.where((t) {
      return t.dateTime.isAfter(startDate) && t.dateTime.isBefore(now);
    }).toList();
    
    // Update category breakdown and other metrics for the filtered range
    _categoryBreakdown = _analyticsService.getCategoryBreakdown(filteredTransactions);
    _totalIncome = _analyticsService.getTotalIncome(filteredTransactions);
    _totalExpense = _analyticsService.getTotalExpense(filteredTransactions);
    _balance = _analyticsService.getBalance(filteredTransactions);
    _uselessSpends = _analyticsService.getUselessSpends(filteredTransactions);
    _uselessSpendPercentage = _analyticsService.getUselessSpendPercentage(filteredTransactions);
    _biggestExpense = _analyticsService.getBiggestExpense(filteredTransactions);
    _topCategory = _analyticsService.getTopSpendingCategory(filteredTransactions);
    
    notifyListeners();
  }

  int getMonthsForRange(TimeRange range, List<TransactionModel> allTransactions) {
    switch (range) {
      case TimeRange.oneMonth:
        return 1;
      case TimeRange.threeMonths:
        return 3;
      case TimeRange.sixMonths:
        return 6;
      case TimeRange.oneYear:
        return 12;
      case TimeRange.all:
        if (allTransactions.isEmpty) return 6;
        final oldest = allTransactions.reduce((a, b) => 
            a.dateTime.isBefore(b.dateTime) ? a : b);
        final now = DateTime.now();
        final difference = (now.year - oldest.dateTime.year) * 12 + 
            now.month - oldest.dateTime.month + 1;
        return difference > 0 ? difference : 1;
    }
  }

  // Get previous period transactions based on current date range
  static List<TransactionModel> getPreviousPeriodTransactions(
    List<TransactionModel> allTransactions,
    DateTime currentStart,
    DateTime currentEnd,
  ) {
    final duration = currentEnd.difference(currentStart);
    final previousStart = currentStart.subtract(duration);
    final previousEnd = currentStart.subtract(const Duration(seconds: 1));

    return allTransactions.where((t) {
      return app_date_utils.DateUtils.isDateInRange(
        t.dateTime,
        previousStart,
        previousEnd,
      );
    }).toList();
  }
}

enum TimeRange {
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  all,
}
