import 'package:flutter/foundation.dart';
import '../data/models/transaction_model.dart';
import '../data/models/otp_model.dart';
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
  List<OtpModel> _allOtps = [];
  bool _isLoading = false;
  bool _isSyncing = false; // separate flag for SMS sync
  String? _error;

  // Filters
  DateRangeType _dateRangeType = DateRangeType.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String? _selectedCategory;
  String? _selectedBank;
  String? _selectedApp;
  int? _selectedYear;
  bool? _selectedType; // null = all, true = credit, false = debit
  bool _onlyWastedSpends = false;

  // Getters
  List<TransactionModel> get allTransactions => _allTransactions;
  List<TransactionModel> get filteredTransactions => _filteredTransactions;
  List<OtpModel> get allOtps => _allOtps;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  DateRangeType get dateRangeType => _dateRangeType;
  String? get selectedCategory => _selectedCategory;
  String? get selectedBank => _selectedBank;
  String? get selectedApp => _selectedApp;
  int? get selectedYear => _selectedYear;
  bool? get selectedType => _selectedType;
  bool get onlyWastedSpends => _onlyWastedSpends;

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

  // Get distinct years from transactions
  List<int> get availableYears {
    final years = _allTransactions.map((t) => t.dateTime.year).toSet().toList();
    if (!years.contains(DateTime.now().year)) {
      years.add(DateTime.now().year);
    }
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  // Get distinct apps/merchants
  List<String> get availableApps {
    final apps = _allTransactions
        .where((t) => !t.isCredit)
        .map((t) => _cleanAppName(t.description))
        .where((name) => name.isNotEmpty && name != 'Transaction' && name != 'Other Merchant')
        .toSet()
        .toList();
    apps.sort();
    return apps;
  }

  // Initialize and load transactions
  Future<void> initialize() async {
    await loadTransactions();
    _startSmsListener();
    // Non-blocking auto-sync for any new SMS received while app was closed
    syncFromSMS(limit: 50);
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
      
      // Collect OTPs
      _allOtps = List<OtpModel>.from(_smsService.cachedOtps);

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

        // 1. Try AI Assistant parsing first with timeout
        try {
          final aiResult = await _smsService.parseSmsWithAi(sms['body'])
              .timeout(const Duration(seconds: 8), onTimeout: () => null);
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
          newTransactions.add(transaction);
          parsed++;
        } else {
          failed++;
        }
      }

      print('Sync results: Parsed=$parsed, Skipped=$skipped, Failed=$failed');

      // Save new transactions
      if (newTransactions.isNotEmpty) {
        await _repository.addTransactions(newTransactions);
        print('Successfully saved ${newTransactions.length} transactions');
      }

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

  // Start listening for new incoming SMS
  void _startSmsListener() {
    _smsService.listenForNewSMS().listen((sms) async {
      try {
        // Handle incoming OTP directly
        if (sms['isOtp'] == true && sms['otp'] != null) {
          final otp = sms['otp'] as OtpModel;
          if (!_allOtps.any((o) => o.code == otp.code && o.dateTime == otp.dateTime)) {
            _allOtps.insert(0, otp);
            notifyListeners();
          }
          return;
        }

        final body = sms['body'] as String? ?? '';
        final sender = sms['sender'] as String? ?? '';
        final date = sms['date'] as DateTime? ?? DateTime.now();

        if (body.isEmpty) return;
        print('=== New Incoming SMS Detected ===');

        // Check if transaction already exists in database
        final exists = await _repository.transactionExists(body);
        if (!exists) {
          TransactionModel? transaction;

          // 1. Try Gemini AI parsing & categorization first
          try {
            print('Categorizing new SMS with Gemini AI...');
            final aiResult = await _smsService.parseSmsWithAi(body)
                .timeout(const Duration(seconds: 8), onTimeout: () => null);
            if (aiResult != null && aiResult['isTransaction'] != false) {
              transaction = _parserService.createTransactionFromAiResult(
                aiResult: aiResult,
                smsBody: body,
                sender: sender,
                receivedDate: date,
              );
            }
          } catch (e) {
            print('Gemini AI parsing failed, falling back to regex: $e');
          }

          // 2. Fallback to regex parsing if AI failed or unavailable
          if (transaction == null) {
            transaction = _parserService.parseSMS(
              smsBody: body,
              sender: sender,
              receivedDate: date,
            );
          }

          if (transaction != null) {
            // Save transaction to local database
            await _repository.addTransaction(transaction);
            
            // Show transaction notification with category
            await _notificationService.showTransactionNotification(transaction);
            
            // Reload all transactions to instantly update expense tracker & dashboard
            await loadTransactions();
            print('Expense tracker updated with new transaction!');
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

  // Set app/merchant filter
  void setAppFilter(String? app) {
    _selectedApp = app;
    _applyFilters();
    notifyListeners();
  }

  // Set year filter
  void setYearFilter(int? year) {
    _selectedYear = year;
    _applyFilters();
    notifyListeners();
  }

  // Set waste filter
  void setOnlyWastedFilter(bool value) {
    _onlyWastedSpends = value;
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
    _dateRangeType = DateRangeType.all;
    _selectedCategory = null;
    _selectedBank = null;
    _selectedApp = null;
    _selectedYear = null;
    _selectedType = null;
    _onlyWastedSpends = false;
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
        startDate = DateTime(now.year, now.month - 5, 1);
        endDate = app_date_utils.DateUtils.endOfToday;
        break;
      case DateRangeType.year:
        final now = DateTime.now();
        startDate = DateTime(now.year - 1, now.month, 1);
        endDate = app_date_utils.DateUtils.endOfToday;
        break;
      case DateRangeType.all:
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

    // Apply year filter
    if (_selectedYear != null) {
      filtered = filtered.where((t) => t.dateTime.year == _selectedYear).toList();
    }

    // Apply category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((t) => t.category == _selectedCategory).toList();
    }

    // Apply bank filter
    if (_selectedBank != null) {
      filtered = filtered.where((t) => t.bankName == _selectedBank).toList();
    }

    // Apply app/merchant filter
    if (_selectedApp != null) {
      filtered = filtered.where((t) => _cleanAppName(t.description).toLowerCase() == _selectedApp!.toLowerCase()).toList();
    }

    // Apply waste filter
    if (_onlyWastedSpends) {
      filtered = filtered.where((t) => !t.isCredit && t.isUselessSpend()).toList();
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

  @override
  void dispose() {
    _smsService.dispose();
    super.dispose();
  }
}
