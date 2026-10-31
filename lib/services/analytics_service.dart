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
  // Get App spending breakdown (e.g. Swiggy, Amazon, Zomato, Uber, Blinkit)
  Map<String, double> getAppSpendingBreakdown(List<TransactionModel> transactions) {
    final breakdown = <String, double>{};
    for (final t in transactions) {
      if (!t.isCredit) {
        final app = _cleanAppName(t.description);
        breakdown[app] = (breakdown[app] ?? 0.0) + t.amount;
      }
    }
    return breakdown;
  }

  // Get Top Spending Apps with percentages
  List<AppSpendItem> getTopAppSpends(List<TransactionModel> transactions, {int limit = 8}) {
    final expenses = transactions.where((t) => !t.isCredit).toList();
    if (expenses.isEmpty) return [];

    final totalExpense = expenses.fold<double>(0.0, (sum, t) => sum + t.amount);
    final appTotals = <String, double>{};
    final appCounts = <String, int>{};

    for (final t in expenses) {
      final app = _cleanAppName(t.description);
      appTotals[app] = (appTotals[app] ?? 0.0) + t.amount;
      appCounts[app] = (appCounts[app] ?? 0) + 1;
    }

    final sortedEntries = appTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.take(limit).map((entry) {
      final spent = entry.value;
      final count = appCounts[entry.key] ?? 1;
      final percentage = totalExpense > 0 ? (spent / totalExpense) * 100 : 0.0;
      return AppSpendItem(
        appName: entry.key,
        totalSpent: spent,
        count: count,
        percentage: percentage,
      );
    }).toList();
  }

  // Get Bank spending & credit breakdown
  Map<String, Map<String, double>> getBankBreakdown(List<TransactionModel> transactions) {
    final breakdown = <String, Map<String, double>>{};
    for (final t in transactions) {
      final bank = t.bankName.isNotEmpty && t.bankName != 'Unknown' ? t.bankName : 'Other Bank';
      if (!breakdown.containsKey(bank)) {
        breakdown[bank] = {'debit': 0.0, 'credit': 0.0, 'count': 0.0};
      }
      if (t.isCredit) {
        breakdown[bank]!['credit'] = (breakdown[bank]!['credit'] ?? 0.0) + t.amount;
      } else {
        breakdown[bank]!['debit'] = (breakdown[bank]!['debit'] ?? 0.0) + t.amount;
      }
      breakdown[bank]!['count'] = (breakdown[bank]!['count'] ?? 0.0) + 1;
    }
    return breakdown;
  }

  // Wasted money breakdown by app
  Map<String, double> getWastedMoneyByApp(List<TransactionModel> transactions) {
    final waste = <String, double>{};
    for (final t in transactions) {
      if (!t.isCredit && _categorizationService.isUselessSpend(t.category)) {
        final app = _cleanAppName(t.description);
        waste[app] = (waste[app] ?? 0.0) + t.amount;
      }
    }
    return waste;
  }

  // AI-inspired smart suggestions on what expenses can be ignored / cut down
  List<AiExpenseSuggestion> getSmartSavingsSuggestions(List<TransactionModel> transactions) {
    final suggestions = <AiExpenseSuggestion>[];
    final expenses = transactions.where((t) => !t.isCredit).toList();
    if (expenses.isEmpty) return [];

    final totalExpense = expenses.fold<double>(0.0, (sum, t) => sum + t.amount);
    final appTotals = <String, double>{};
    final appCounts = <String, int>{};

    for (final t in expenses) {
      final app = _cleanAppName(t.description);
      appTotals[app] = (appTotals[app] ?? 0.0) + t.amount;
      appCounts[app] = (appCounts[app] ?? 0) + 1;
    }

    // 1. Food Delivery Overuse
    final foodExpenses = expenses.where((t) => t.category == 'Food Delivery').toList();
    final foodTotal = foodExpenses.fold<double>(0.0, (s, t) => s + t.amount);
    if (foodTotal > 1000) {
      final potential = foodTotal * 0.45;
      suggestions.add(AiExpenseSuggestion(
        title: 'High Food Delivery Spend',
        description: 'You placed ${foodExpenses.length} food orders totaling ₹${foodTotal.toStringAsFixed(0)}. Cooking at home or cutting 40% of orders can save significantly.',
        potentialSavings: potential,
        severity: foodTotal > 4000 ? 'high' : 'medium',
        category: 'Food Delivery',
      ));
    }

    // 2. Subscriptions Bloat
    final subExpenses = expenses.where((t) => t.category == 'Subscriptions').toList();
    final subTotal = subExpenses.fold<double>(0.0, (s, t) => s + t.amount);
    if (subTotal > 500) {
      final potential = subTotal * 0.50;
      suggestions.add(AiExpenseSuggestion(
        title: 'Recurring Subscriptions Check',
        description: 'You spent ₹${subTotal.toStringAsFixed(0)} across ${subExpenses.length} subscription services. Review and pause unused OTT or streaming plans.',
        potentialSavings: potential,
        severity: 'medium',
        category: 'Subscriptions',
      ));
    }

    // 3. Impulsive E-Commerce / Shopping
    final shopExpenses = expenses.where((t) => t.category == 'Online Shopping').toList();
    final shopTotal = shopExpenses.fold<double>(0.0, (s, t) => s + t.amount);
    if (shopTotal > 2000) {
      final potential = shopTotal * 0.35;
      suggestions.add(AiExpenseSuggestion(
        title: 'Discretionary Shopping Impulse',
        description: 'Online shopping accounted for ₹${shopTotal.toStringAsFixed(0)}. Applying the 48-hour rule before purchasing non-essentials could save money.',
        potentialSavings: potential,
        severity: shopTotal > 6000 ? 'high' : 'low',
        category: 'Online Shopping',
      ));
    }

    // 4. Quick Commerce Micro-Orders (Zepto/Blinkit/Instamart)
    final quickCommerce = expenses.where((t) {
      final desc = t.description.toLowerCase();
      return desc.contains('blinkit') || desc.contains('zepto') || desc.contains('instamart');
    }).toList();
    if (quickCommerce.length >= 4) {
      final quickTotal = quickCommerce.fold<double>(0.0, (s, t) => s + t.amount);
      suggestions.add(AiExpenseSuggestion(
        title: 'Frequent Quick Commerce Deliveries',
        description: '${quickCommerce.length} separate orders detected (₹${quickTotal.toStringAsFixed(0)}). Batching orders weekly avoids repeat delivery surge fees.',
        potentialSavings: quickCommerce.length * 35.0,
        severity: 'low',
        category: 'Groceries',
      ));
    }

    // 5. General Discretionary / Useless Spend Check
    final uselessTotal = _categorizationService.getTotalUselessSpends(transactions);
    final uselessPct = totalExpense > 0 ? (uselessTotal / totalExpense) * 100 : 0.0;
    if (uselessPct > 25) {
      suggestions.add(AiExpenseSuggestion(
        title: 'Waste of Money Alert: ${uselessPct.toStringAsFixed(0)}% Discretionary',
        description: '₹${uselessTotal.toStringAsFixed(0)} went into dining out, shopping sprees, and entertainment. Reducing these by 30% boosts your monthly savings.',
        potentialSavings: uselessTotal * 0.30,
        severity: uselessPct > 45 ? 'high' : 'medium',
        category: 'Other',
      ));
    }

    return suggestions;
  }

  // Clean app name helper
  String _cleanAppName(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains('swiggy')) return 'Swiggy';
    if (lower.contains('zomato')) return 'Zomato';
    if (lower.contains('amazon')) return 'Amazon';
    if (lower.contains('flipkart')) return 'Flipkart';
    if (lower.contains('blinkit')) return 'Blinkit';
    if (lower.contains('zepto')) return 'Zepto';
    if (lower.contains('instamart')) return 'Instamart';
    if (lower.contains('uber')) return 'Uber';
    if (lower.contains('ola')) return 'Ola';
    if (lower.contains('rapido')) return 'Rapido';
    if (lower.contains('myntra')) return 'Myntra';
    if (lower.contains('ajio')) return 'Ajio';
    if (lower.contains('meesho')) return 'Meesho';
    if (lower.contains('netflix')) return 'Netflix';
    if (lower.contains('spotify')) return 'Spotify';
    if (lower.contains('prime')) return 'Prime';
    if (lower.contains('hotstar')) return 'Hotstar';
    if (lower.contains('bigbasket')) return 'BigBasket';
    if (lower.contains('dmart')) return 'DMart';
    if (lower.contains('paytm')) return 'Paytm';
    if (lower.contains('phonepe')) return 'PhonePe';
    if (lower.contains('google')) return 'Google';
    if (lower.contains('cred')) return 'Cred';
    if (lower.contains('irctc')) return 'IRCTC';
    if (lower.contains('makemytrip')) return 'MakeMyTrip';
    if (lower.contains('bookmyshow')) return 'BookMyShow';

    final cleaned = raw.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    if (cleaned.isEmpty) return 'Other Merchant';
    final words = cleaned.split(RegExp(r'\s+'));
    return words.take(2).join(' ');
  }
}

// App spend item model
class AppSpendItem {
  final String appName;
  final double totalSpent;
  final int count;
  final double percentage;

  AppSpendItem({
    required this.appName,
    required this.totalSpent,
    required this.count,
    required this.percentage,
  });
}

// AI expense suggestion model
class AiExpenseSuggestion {
  final String title;
  final String description;
  final double potentialSavings;
  final String severity; // 'high', 'medium', 'low'
  final String category;
  final String app;

  AiExpenseSuggestion({
    required this.title,
    required this.description,
    required this.potentialSavings,
    required this.severity,
    required this.category,
    this.app = '',
  });
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
