import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('transactions.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';
    const textType = 'TEXT NOT NULL';

    await db.execute('''
      CREATE TABLE transactions (
        id $idType,
        dateTime $intType,
        amount $realType,
        isCredit $intType,
        category $textType,
        description $textType,
        bankName TEXT,
        rawSms $textType
      )
    ''');

    // Create indexes for better query performance
    await db.execute('''
      CREATE INDEX idx_dateTime ON transactions(dateTime)
    ''');

    await db.execute('''
      CREATE INDEX idx_category ON transactions(category)
    ''');

    await db.execute('''
      CREATE INDEX idx_isCredit ON transactions(isCredit)
    ''');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // Clear all data (for testing or reset)
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('transactions');
  }
}
