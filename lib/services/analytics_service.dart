import '../data/models/transaction_model.dart';
import '../core/utils/date_utils.dart' as app_date_utils;
import '../services/categorization_service.dart';

class AnalyticsService {
  final CategorizationService _categorizationService = CategorizationService();

  // Get total income for a date range
  double getTotalIncome(List<TransactionModel> transactions) {
    return transactions
        .where((t) => t.isCredit)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // Get total expense for a date range
  double getTotalExpense(List<TransactionModel> transactions) {
    return transactions
        .where((t) => !t.isCredit)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // Get balance (income - expense)
  double getBalance(List<TransactionModel> transactions) {
    return getTotalIncome(transactions) - getTotalExpense(transactions);
  }

  // Get total useless spends
  double getUselessSpends(List<TransactionModel> transactions) {
    return _categorizationService.getTotalUselessSpends(transactions);
  }

  // Get useless spend percentage
  double getUselessSpendPercentage(List<TransactionModel> transactions) {
    return _categorizationService.getUselessSpendPercentage(transactions);
  }

  // Get category breakdown
  Map<String, double> getCategoryBreakdown(List<TransactionModel> transactions) {
    return _categorizationService.getCategoryBreakdown(transactions);
  }

  // Get biggest expense
  TransactionModel? getBiggestExpense(List<TransactionModel> transactions) {
    final expenses = transactions.where((t) => !t.isCredit).toList();
    
    if (expenses.isEmpty) return null;

    var biggest = expenses.first;
    for (final expense in expenses) {
      if (expense.amount > biggest.amount) {
        biggest = expense;
      }
    }

    return biggest;
  }

  // Get top spending category
  String? getTopSpendingCategory(List<TransactionModel> transactions) {
    return _categorizationService.getTopSpendingCategory(transactions);
  }

  // Get spending trend (monthly data for last N months)
  List<MonthlyData> getSpendingTrend(
    List<TransactionModel> allTransactions,
    int months,
  ) {
    final monthlyData = <MonthlyData>[];
    final monthStarts = app_date_utils.DateUtils.getLastNMonthsStarts(months);

    for (final monthStart in monthStarts) {
      final monthEnd = DateTime(
        monthStart.year,
        monthStart.month + 1,
        0,
        23,
        59,
        59,
      );

      final monthTransactions = allTransactions.where((t) {
        return app_date_utils.DateUtils.isDateInRange(
          t.dateTime,
          monthStart,
          monthEnd,
        );
      }).toList();

      monthlyData.add(MonthlyData(
        month: monthStart,
        income: getTotalIncome(monthTransactions),
        expense: getTotalExpense(monthTransactions),
        balance: getBalance(monthTransactions),
      ));
    }

    return monthlyData;
  }

  // Generate insights
  List<String> generateInsights(
    List<TransactionModel> currentTransactions,
    List<TransactionModel> previousTransactions,
  ) {
    final insights = <String>[];

    // Current period stats
    final currentExpense = getTotalExpense(currentTransactions);
    final currentIncome = getTotalIncome(currentTransactions);
    final currentUseless = getUselessSpends(currentTransactions);
    final currentUselessPercent = getUselessSpendPercentage(currentTransactions);

    // Previous period stats
    final previousExpense = getTotalExpense(previousTransactions);
    final previousIncome = getTotalIncome(previousTransactions);

    // Insight 1: Spending comparison
    if (previousExpense > 0) {
      final spendingChange = ((currentExpense - previousExpense) / previousExpense) * 100;
      
      if (spendingChange > 20) {
        insights.add(
          '⚠️ You spent ${spendingChange.toStringAsFixed(0)}% more this period compared to last period',
        );
      } else if (spendingChange < -20) {
        insights.add(
          '✅ Great! You spent ${spendingChange.abs().toStringAsFixed(0)}% less this period',
        );
      }
    }

    // Insight 2: Income comparison
    if (previousIncome > 0) {
      final incomeChange = ((currentIncome - previousIncome) / previousIncome) * 100;
      
      if (incomeChange > 10) {
        insights.add(
          '💰 Your income increased by ${incomeChange.toStringAsFixed(0)}% this period',
        );
      } else if (incomeChange < -10) {
        insights.add(
          '📉 Your income decreased by ${incomeChange.abs().toStringAsFixed(0)}% this period',
        );
      }
    }

    // Insight 3: Useless spends
    if (currentUselessPercent > 40) {
      insights.add(
        '🛒 ${currentUselessPercent.toStringAsFixed(0)}% of your expenses are non-essential. Consider reducing these.',
      );
    } else if (currentUselessPercent < 20) {
      insights.add(
        '👍 Only ${currentUselessPercent.toStringAsFixed(0)}% of expenses are non-essential. Keep it up!',
      );
    }

    // Insight 4: Top category
    final topCategory = getTopSpendingCategory(currentTransactions);
    if (topCategory != null) {
      final categoryAmount = getCategoryBreakdown(currentTransactions)[topCategory] ?? 0;
      insights.add(
        '📊 Your top spending category: $topCategory (₹${categoryAmount.toStringAsFixed(0)})',
      );
    }

    // Insight 5: Savings rate
    if (currentIncome > 0) {
      final savingsRate = ((currentIncome - currentExpense) / currentIncome) * 100;
      
      if (savingsRate < 10) {
        insights.add(
          '⚠️ Your savings rate is only ${savingsRate.toStringAsFixed(0)}%. Try to save more!',
        );
      } else if (savingsRate > 30) {
        insights.add(
          '🎉 Excellent! You\'re saving ${savingsRate.toStringAsFixed(0)}% of your income',
        );
      }
    }

    // Insight 6: Biggest expense
    final biggestExpense = getBiggestExpense(currentTransactions);
    if (biggestExpense != null && biggestExpense.amount > currentExpense * 0.2) {
      insights.add(
        '💸 Your biggest expense: ₹${biggestExpense.amount.toStringAsFixed(0)} on ${biggestExpense.category}',
      );
    }

    return insights;
  }

  // Get transaction count by category
  Map<String, int> getTransactionCountByCategory(
    List<TransactionModel> transactions,
  ) {
    final counts = <String, int>{};

    for (final transaction in transactions) {
      if (!transaction.isCredit) {
        counts[transaction.category] = (counts[transaction.category] ?? 0) + 1;
      }
    }

    return counts;
  }

  // Get average transaction amount
  double getAverageTransactionAmount(List<TransactionModel> transactions) {
    if (transactions.isEmpty) return 0.0;
    
    final total = transactions.fold<double>(0.0, (sum, t) => sum + t.amount);
    return total / transactions.length;
  }
}

// Monthly data model for trends
class MonthlyData {
  final DateTime month;
  final double income;
  final double expense;
  final double balance;

  MonthlyData({
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
  });

  String get monthName {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month.month - 1];
  }
}
