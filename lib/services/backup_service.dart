import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/otp_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/database/database_helper.dart';

class BackupService {
  static final BackupService instance = BackupService._internal();
  BackupService._internal();

  final TransactionRepository _repository = TransactionRepository();

  /// Create full backup file containing all transactions, OTPs, and schema metadata
  Future<File> exportFullBackup(List<OtpModel> otps) async {
    final transactions = await _repository.getAllTransactions();

    final backupData = {
      'app': 'FinTracker',
      'version': '1.0.0',
      'exportDate': DateTime.now().toIso8601String(),
      'totalTransactions': transactions.length,
      'totalOtps': otps.length,
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'otps': otps.map((o) => o.toMap()).toList(),
    };

    final jsonString = jsonEncode(backupData);

    // Save to Downloads / Documents directory
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupFile = File('${directory.path}/FinTracker_Backup_$timestamp.json');

    await backupFile.writeAsString(jsonString);
    return backupFile;
  }

  /// Import full backup file and restore into local SQLite database
  Future<Map<String, int>> importFullBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Selected backup file does not exist');
    }

    final content = await file.readAsString();
    final dynamic decoded = jsonDecode(content);

    if (decoded is! Map<String, dynamic> || decoded['app'] != 'FinTracker') {
      throw Exception('Invalid FinTracker backup file format');
    }

    final rawTxns = decoded['transactions'] as List<dynamic>? ?? [];
    final rawOtps = decoded['otps'] as List<dynamic>? ?? [];

    int importedTxns = 0;
    final List<TransactionModel> txnsToInsert = [];

    for (final item in rawTxns) {
      try {
        final map = Map<String, dynamic>.from(item as Map);
        final txn = TransactionModel.fromMap(map);
        final exists = await _repository.transactionExists(txn.rawSms);
        if (!exists) {
          txnsToInsert.add(txn);
          importedTxns++;
        }
      } catch (_) {}
    }

    if (txnsToInsert.isNotEmpty) {
      await _repository.addTransactions(txnsToInsert);
    }

    return {
      'transactions': importedTxns,
      'otps': rawOtps.length,
    };
  }
}
