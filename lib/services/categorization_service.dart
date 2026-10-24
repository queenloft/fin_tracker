import '../core/constants/app_constants.dart';
import '../data/models/transaction_model.dart';

class CategorizationService {
  // Categorize a transaction based on description, merchant, and raw SMS
  String categorizeTransaction({
    required String description,
    required String merchant,
    required bool isCredit,
    String? rawSms,
  }) {
    final lowerDescription = description.toLowerCase();
    final lowerMerchant = merchant.toLowerCase();
    final lowerRaw = (rawSms ?? '').toLowerCase();
    final combinedText = '$lowerDescription $lowerMerchant $lowerRaw';

    // Special handling for credit transactions
    if (isCredit) {
      // Check for salary keywords
      if (_containsAnyKeyword(combinedText, AppConstants.merchantKeywords[AppConstants.categorySalary] ?? [])) {
        return AppConstants.categorySalary;
      }
      
      // Check for refund keywords
      if (_containsAnyKeyword(combinedText, AppConstants.merchantKeywords[AppConstants.categoryRefund] ?? [])) {
        return AppConstants.categoryRefund;
      }
      
      // Check for investment returns
      if (_containsAnyKeyword(combinedText, AppConstants.merchantKeywords[AppConstants.categoryInvestment] ?? [])) {
        return AppConstants.categoryInvestment;
      }
      
      // Default for other credits
      return AppConstants.categoryOther;
    }

    // For debit transactions, check each category
    for (final entry in AppConstants.merchantKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      if (_containsAnyKeyword(combinedText, keywords)) {
        return category;
      }
    }

    // Default category
    return AppConstants.categoryOther;
  }

  // Check if text contains any of the keywords
  bool _containsAnyKeyword(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  // Check if a category is considered "useless spend"
  bool isUselessSpend(String category) {
    return AppConstants.uselessSpendCategories.contains(category);
  }

  // Calculate useless spend percentage
  double getUselessSpendPercentage(List<TransactionModel> transactions) {
    if (transactions.isEmpty) return 0.0;

    final expenses = transactions.where((t) => !t.isCredit).toList();
    if (expenses.isEmpty) return 0.0;

    final totalExpense = expenses.fold<double>(
      0.0,
      (sum, t) => sum + t.amount,
    );

    final uselessExpense = expenses
        .where((t) => isUselessSpend(t.category))
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    return (uselessExpense / totalExpense) * 100;
  }

  // Get total useless spends
  double getTotalUselessSpends(List<TransactionModel> transactions) {
    return transactions
        .where((t) => !t.isCredit && isUselessSpend(t.category))
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // Get category breakdown
  Map<String, double> getCategoryBreakdown(List<TransactionModel> transactions) {
    final breakdown = <String, double>{};

    for (final transaction in transactions) {
      if (!transaction.isCredit) {
        breakdown[transaction.category] = 
            (breakdown[transaction.category] ?? 0.0) + transaction.amount;
      }
    }

    return breakdown;
  }

  // Get top spending category
  String? getTopSpendingCategory(List<TransactionModel> transactions) {
    final breakdown = getCategoryBreakdown(transactions);
    
    if (breakdown.isEmpty) return null;

    var topCategory = breakdown.keys.first;
    var maxAmount = breakdown[topCategory]!;

    for (final entry in breakdown.entries) {
      if (entry.value > maxAmount) {
        maxAmount = entry.value;
        topCategory = entry.key;
      }
    }

    return topCategory;
  }

  // Recategorize a transaction (for manual corrections)
  String recategorizeTransaction(String newCategory) {
    // Validate category
    if (AppConstants.allCategories.contains(newCategory)) {
      return newCategory;
    }
    return AppConstants.categoryOther;
  }
}
