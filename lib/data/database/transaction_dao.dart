import 'package:sqflite/sqflite.dart';
import '../models/transaction_model.dart';
import 'database_helper.dart';

class TransactionDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Insert a new transaction
  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await _dbHelper.database;
    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert multiple transactions
  Future<void> insertTransactions(List<TransactionModel> transactions) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    
    for (final transaction in transactions) {
      batch.insert(
        'transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  // Get all transactions
  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'dateTime DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }

  // Get transactions by date range
  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'dateTime >= ? AND dateTime <= ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'dateTime DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }

  // Get transactions by category
  Future<List<TransactionModel>> getTransactionsByCategory(
    String category,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'dateTime DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }

  // Get transactions by type (credit/debit)
  Future<List<TransactionModel>> getTransactionsByType(
    bool isCredit,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'isCredit = ?',
      whereArgs: [isCredit ? 1 : 0],
      orderBy: 'dateTime DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }

  // Get transactions with multiple filters
  Future<List<TransactionModel>> getFilteredTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    bool? isCredit,
  }) async {
    final db = await _dbHelper.database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause += 'dateTime >= ? AND dateTime <= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    if (category != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'category = ?';
      whereArgs.add(category);
    }

    if (isCredit != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'isCredit = ?';
      whereArgs.add(isCredit ? 1 : 0);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'dateTime DESC',
    );

    return List.generate(maps.length, (i) {
      return TransactionModel.fromMap(maps[i]);
    });
  }

  // Get transaction by ID
  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  // Update transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await _dbHelper.database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // Delete transaction
  Future<void> deleteTransaction(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete all transactions
  Future<void> deleteAllTransactions() async {
    final db = await _dbHelper.database;
    await db.delete('transactions');
  }

  // Get count of transactions
  Future<int> getTransactionCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM transactions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Check if transaction exists (by raw SMS to avoid duplicates)
  Future<bool> transactionExists(String rawSms) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'rawSms = ?',
      whereArgs: [rawSms],
      limit: 1,
    );

    return maps.isNotEmpty;
  }
}
