import '../models/transaction_model.dart';
import '../database/transaction_dao.dart';

class TransactionRepository {
  final TransactionDao _dao = TransactionDao();

  // Add a new transaction
  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      await _dao.insertTransaction(transaction);
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  // Add multiple transactions
  Future<void> addTransactions(List<TransactionModel> transactions) async {
    try {
      await _dao.insertTransactions(transactions);
    } catch (e) {
      throw Exception('Failed to add transactions: $e');
    }
  }

  // Get all transactions
  Future<List<TransactionModel>> getAllTransactions() async {
    try {
      return await _dao.getAllTransactions();
    } catch (e) {
      throw Exception('Failed to get transactions: $e');
    }
  }

  // Get transactions by date range
  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      return await _dao.getTransactionsByDateRange(startDate, endDate);
    } catch (e) {
      throw Exception('Failed to get transactions by date range: $e');
    }
  }

  // Get transactions by category
  Future<List<TransactionModel>> getTransactionsByCategory(
    String category,
  ) async {
    try {
      return await _dao.getTransactionsByCategory(category);
    } catch (e) {
      throw Exception('Failed to get transactions by category: $e');
    }
  }

  // Get transactions by type
  Future<List<TransactionModel>> getTransactionsByType(bool isCredit) async {
    try {
      return await _dao.getTransactionsByType(isCredit);
    } catch (e) {
      throw Exception('Failed to get transactions by type: $e');
    }
  }

  // Get filtered transactions
  Future<List<TransactionModel>> getFilteredTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    bool? isCredit,
  }) async {
    try {
      return await _dao.getFilteredTransactions(
        startDate: startDate,
        endDate: endDate,
        category: category,
        isCredit: isCredit,
      );
    } catch (e) {
      throw Exception('Failed to get filtered transactions: $e');
    }
  }

  // Get transaction by ID
  Future<TransactionModel?> getTransactionById(String id) async {
    try {
      return await _dao.getTransactionById(id);
    } catch (e) {
      throw Exception('Failed to get transaction by ID: $e');
    }
  }

  // Update transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      await _dao.updateTransaction(transaction);
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  // Delete transaction
  Future<void> deleteTransaction(String id) async {
    try {
      await _dao.deleteTransaction(id);
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // Delete all transactions
  Future<void> deleteAllTransactions() async {
    try {
      await _dao.deleteAllTransactions();
    } catch (e) {
      throw Exception('Failed to delete all transactions: $e');
    }
  }

  // Get transaction count
  Future<int> getTransactionCount() async {
    try {
      return await _dao.getTransactionCount();
    } catch (e) {
      throw Exception('Failed to get transaction count: $e');
    }
  }

  // Check if transaction exists
  Future<bool> transactionExists(String rawSms) async {
    try {
      return await _dao.transactionExists(rawSms);
    } catch (e) {
      throw Exception('Failed to check transaction existence: $e');
    }
  }
}
