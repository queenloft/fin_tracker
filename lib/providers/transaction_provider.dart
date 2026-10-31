import 'package:flutter/foundation.dart';
import '../data/models/transaction_model.dart';
import '../data/repositories/transaction_repository.dart';
import '../services/sms_service.dart';
import '../services/parser_service.dart';
import '../services/notification_service.dart';
import '../core/utils/date_utils.dart' as app_date_utils;

enum DateRangeType { today, week, month, sixMonths, year, all, custom }

class TransactionProvider with ChangeNotifier {
  final TransactionRepository _repository = TransactionRepository();
  final SmsService _smsService = SmsService();
  final ParserService _parserService = ParserService();
  final NotificationService _notificationService = NotificationService.instance;

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _filteredTransactions = [];
  bool _isLoading = false;
  bool _isSyncing = false; // separate flag for SMS sync
  String? _error;
  // Filters
  DateRangeType _dateRangeType = DateRangeType.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String? _selectedCategory;
  String? _selectedBank;
  bool? _selectedType; // null = all, true = credit, false = debit

  // Getters
  List<TransactionModel> get allTransactions => _allTransactions;
  List<TransactionModel> get filteredTransactions => _filteredTransactions;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  DateRangeType get dateRangeType => _dateRangeType;
  String? get selectedCategory => _selectedCategory;
  String? get selectedBank => _selectedBank;
  bool? get selectedType => _selectedType;

  // Get list of unique banks from transactions
  List<String> get availableBanks {
    final banks = _allTransactions
        .map((t) => t.bankName)
        .where((name) => name.isNotEmpty && name != 'Unknown')
        .toSet()
        .toList();
    banks.sort();
    return banks;
  }

  // Initialize and load transactions
  Future<void> initialize() async {
    await loadTransactions();
    _startSmsListener();
  }

  // Load all transactions from database
  Future<void> loadTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allTransactions = await _repository.getAllTransactions();
      _applyFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Read existing SMS and parse transactions
  Future<void> syncFromSMS({int? limit}) async {
    if (_isSyncing) return; // prevent concurrent syncs
    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      print('=== Starting SMS Sync ===');
      // Read SMS
      final smsList = await _smsService.readExistingSMS(limit: limit);
      print('Read ${smsList.length} SMS messages');
      
      // Parse SMS to transactions
      final newTransactions = <TransactionModel>[];
      int skipped = 0;
      int parsed = 0;
      int failed = 0;
      
      for (final sms in smsList) {
        // Check if transaction already exists
        final exists = await _repository.transactionExists(sms['body']);
        if (exists) {
          skipped++;
          continue;
        }
        
        TransactionModel? transaction;

        // 1. Try AI Assistant parsing first
        try {
          final aiResult = await _smsService.parseSmsWithAi(sms['body'])
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (aiResult != null && aiResult['isTransaction'] != false) {
            transaction = _parserService.createTransactionFromAiResult(
              aiResult: aiResult,
              smsBody: sms['body'],
              sender: sms['sender'],
              receivedDate: sms['date'],
            );
          }
        } catch (e) {
          print('AI parsing in sync skipped/failed: $e');
        }
        
        // 2. Fallback to enhanced high-accuracy regex parser
        if (transaction == null) {
          transaction = _parserService.parseSMS(
            smsBody: sms['body'],
            sender: sms['sender'],
            receivedDate: sms['date'],
          );
        }
        
        if (transaction != null) {
          print('Parsed: ${transaction.description}');
          newTransactions.add(transaction);
          parsed++;
        } else {
          print('Failed to parse: ${sms['body']}');
          failed++;
        }
      }

      print('Sync results: Parsed=$parsed, Skipped=$skipped, Failed=$failed');
      print('Saving ${newTransactions.length} new transactions...');

      // Save new transactions
      if (newTransactions.isNotEmpty) {
        await _repository.addTransactions(newTransactions);
        print('Successfully saved ${newTransactions.length} transactions');
      }

      // Switch to 'All Time' view to show imported transactions
      _dateRangeType = DateRangeType.all;

      // Reload transactions
      await loadTransactions();
      _isSyncing = false;
      notifyListeners();
      print('=== SMS Sync Complete ===');
    } catch (e) {
      print('ERROR in syncFromSMS: $e');
      _error = e.toString();
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Start listening for new SMS
  void _startSmsListener() {
    _smsService.listenForNewSMS().listen((sms) async {
      try {
        // Check if transaction already exists
        final exists = await _repository.transactionExists(sms['body']);
        if (!exists) {
          TransactionModel? transaction;

          // Try AI parsing first
          try {
            final aiResult = await _smsService.parseSmsWithAi(sms['body'])
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
            if (aiResult != null && aiResult['isTransaction'] != false) {
              transaction = _parserService.createTransactionFromAiResult(
                aiResult: aiResult,
                smsBody: sms['body'],
                sender: sms['sender'],
                receivedDate: sms['date'],
              );
            }
          } catch (e) {
            print('AI parsing failed, falling back to regex: $e');
          }

          // Fallback to regex parsing if AI failed
          if (transaction == null) {
            transaction = _parserService.parseSMS(
              smsBody: sms['body'],
              sender: sms['sender'],
              receivedDate: sms['date'],
            );
          }

          if (transaction != null) {
            // Save transaction
            await _repository.addTransaction(transaction);
            
            // Show notification
            await _notificationService.showTransactionNotification(transaction);
            
            // Reload transactions
            await loadTransactions();
          }
        }
      } catch (e) {
        print('Error processing new SMS: $e');
      }
    });
  }

  // Add transaction manually
  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      await _repository.addTransaction(transaction);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Delete transaction
  Future<void> deleteTransaction(String id) async {
    try {
      await _repository.deleteTransaction(id);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Update transaction
  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      await _repository.updateTransaction(transaction);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Set date range filter
  void setDateRange(DateRangeType type, {DateTime? start, DateTime? end}) {
    _dateRangeType = type;
    if (type == DateRangeType.custom) {
      _customStartDate = start;
      _customEndDate = end;
    }
    _applyFilters();
    notifyListeners();
  }

  // Set category filter
  void setCategoryFilter(String? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  // Set bank filter
  void setBankFilter(String? bankName) {
    _selectedBank = bankName;
    _applyFilters();
    notifyListeners();
  }

  // Set type filter
  void setTypeFilter(bool? isCredit) {
    _selectedType = isCredit;
    _applyFilters();
    notifyListeners();
  }

  // Clear all filters
  void clearFilters() {
    _dateRangeType = DateRangeType.today;
    _selectedCategory = null;
    _selectedBank = null;
    _selectedType = null;
    _customStartDate = null;
    _customEndDate = null;
    _applyFilters();
    notifyListeners();
  }

  // Apply filters to transactions
  void _applyFilters() {
    var filtered = List<TransactionModel>.from(_allTransactions);

    // Apply date range filter
    DateTime? startDate;
    DateTime? endDate;

    switch (_dateRangeType) {
      case DateRangeType.today:
        startDate = app_date_utils.DateUtils.startOfToday;
        endDate = app_date_utils.DateUtils.endOfToday;
        break;
      case DateRangeType.week:
        startDate = app_date_utils.DateUtils.startOfWeek;
        endDate = app_date_utils.DateUtils.endOfWeek;
        break;
      case DateRangeType.month:
        startDate = app_date_utils.DateUtils.startOfMonth;
        endDate = app_date_utils.DateUtils.endOfMonth;
        break;
      case DateRangeType.sixMonths:
        final now = DateTime.now();
        startDate = DateTime(now.year, now.month - 5, 1); // Start of 6 months ago
        endDate = app_date_utils.DateUtils.endOfToday;
        break;
      case DateRangeType.year:
        final now = DateTime.now();
        startDate = DateTime(now.year - 1, now.month, 1); // Start of 1 year ago
        endDate = app_date_utils.DateUtils.endOfToday;
        break;
      case DateRangeType.all:
        // No date filtering
        break;
      case DateRangeType.custom:
        startDate = _customStartDate;
        endDate = _customEndDate;
        break;
    }

    if (startDate != null && endDate != null) {
      filtered = filtered.where((t) {
        return app_date_utils.DateUtils.isDateInRange(t.dateTime, startDate!, endDate!);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((t) => t.category == _selectedCategory).toList();
    }

    // Apply bank filter
    if (_selectedBank != null) {
      filtered = filtered.where((t) => t.bankName == _selectedBank).toList();
    }

    // Apply type filter
    if (_selectedType != null) {
      filtered = filtered.where((t) => t.isCredit == _selectedType).toList();
    }

    _filteredTransactions = filtered;
  }

  Map<String, DateTime?> getCurrentDateRange() {
    switch (_dateRangeType) {
      case DateRangeType.today:
        return {
          'start': app_date_utils.DateUtils.startOfToday,
          'end': app_date_utils.DateUtils.endOfToday,
        };
      case DateRangeType.week:
        return {
          'start': app_date_utils.DateUtils.startOfWeek,
          'end': app_date_utils.DateUtils.endOfWeek,
        };
      case DateRangeType.month:
        return {
          'start': app_date_utils.DateUtils.startOfMonth,
          'end': app_date_utils.DateUtils.endOfToday,
        };
      case DateRangeType.sixMonths:
        final now = DateTime.now();
        return {
          'start': DateTime(now.year, now.month - 5, 1),
          'end': app_date_utils.DateUtils.endOfToday,
        };
      case DateRangeType.year:
        final now = DateTime.now();
        return {
          'start': DateTime(now.year - 1, now.month, 1),
          'end': app_date_utils.DateUtils.endOfToday,
        };
      case DateRangeType.all:
        return {
          'start': null,
          'end': null,
        };
      case DateRangeType.custom:
        return {
          'start': _customStartDate,
          'end': _customEndDate,
        };
    }
  }

  @override
  void dispose() {
    _smsService.dispose();
    super.dispose();
  }
}
