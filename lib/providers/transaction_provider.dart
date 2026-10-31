import 'package:flutter/foundation.dart';
import '../data/models/transaction_model.dart';
import '../data/models/otp_model.dart';
import '../data/repositories/transaction_repository.dart';
import '../services/sms_service.dart';
import '../services/parser_service.dart';
import '../services/notification_service.dart';
import '../core/utils/date_utils.dart' as app_date_utils;

enum DateRangeType { today, week, month, sixMonths, year, all, custom }

class PayeeSummary {
  final String name;
  final double totalAmount;
  final int count;
  final double percentage;

  PayeeSummary({
    required this.name,
    required this.totalAmount,
    required this.count,
    required this.percentage,
  });
}

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
  String? _selectedPayee;
  int? _selectedYear;
  bool? _selectedType; // null = all, true = credit, false = debit
  bool _onlyWastedSpends = false;

  // OTP Filters
  String? _selectedOtpService;
  String? _selectedOtpSender;

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
  String? get selectedPayee => _selectedPayee;
  int? get selectedYear => _selectedYear;
  bool? get selectedType => _selectedType;
  bool get onlyWastedSpends => _onlyWastedSpends;

  String? get selectedOtpService => _selectedOtpService;
  String? get selectedOtpSender => _selectedOtpSender;

  // Filtered OTPs
  List<OtpModel> get filteredOtps {
    var otps = List<OtpModel>.from(_allOtps);
    if (_selectedOtpService != null) {
      otps = otps.where((o) => o.serviceName.toLowerCase() == _selectedOtpService!.toLowerCase()).toList();
    }
    if (_selectedOtpSender != null) {
      otps = otps.where((o) => o.sender.toLowerCase() == _selectedOtpSender!.toLowerCase()).toList();
    }
    return otps;
  }

  // OTP available filters
  List<String> get availableOtpServices {
    final services = _allOtps.map((o) => o.serviceName).toSet().toList();
    services.sort();
    return services;
  }

  List<String> get availableOtpSenders {
    final senders = _allOtps.map((o) => o.sender).toSet().toList();
    senders.sort();
    return senders;
  }

  // Sum of all amounts for currently filtered transactions
  double get filteredTotalAmount {
    return _filteredTransactions.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  double get filteredExpenseSum {
    return _filteredTransactions
        .where((t) => !t.isCredit)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  double get filteredIncomeSum {
    return _filteredTransactions
        .where((t) => t.isCredit)
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  double get filteredNetBalance => filteredIncomeSum - filteredExpenseSum;

  int get filteredTransactionCount => _filteredTransactions.length;

  bool get hasActiveFilters {
    return _selectedCategory != null ||
        _selectedBank != null ||
        _selectedApp != null ||
        _selectedPayee != null ||
        _selectedYear != null ||
        _selectedType != null ||
        _onlyWastedSpends ||
        _dateRangeType != DateRangeType.all;
  }

  bool get hasActiveOtpFilters {
    return _selectedOtpService != null || _selectedOtpSender != null;
  }

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

  // Get recognized corporate/e-commerce Apps only (Swiggy, Amazon, Uber, Zomato, etc.)
  List<String> get availableApps {
    const recognizedAppNames = [
      'Swiggy', 'Zomato', 'Amazon', 'Flipkart', 'Blinkit', 'Zepto', 'Instamart',
      'Uber', 'Ola', 'Rapido', 'Myntra', 'Ajio', 'Meesho', 'Netflix', 'Spotify',
      'Prime Video', 'Hotstar', 'BigBasket', 'DMart', 'Paytm', 'PhonePe', 'Google Pay',
      'Cred', 'IRCTC', 'MakeMyTrip', 'BookMyShow', 'Dominos', 'McDonalds', 'Starbucks',
      'KFC', 'Pizza Hut', 'Apollo Pharmacy', 'PharmEasy', 'Netmeds', 'Tata 1mg',
      'Zerodha', 'Groww', 'Upstox', 'Airtel', 'Jio', 'Vodafone'
    ];

    final apps = <String>{};
    for (final t in _allTransactions) {
      if (!t.isCredit) {
        final identified = _identifyCorporateApp(t.description);
        if (identified != null) {
          apps.add(identified);
        }
      }
    }
    final sorted = apps.toList()..sort();
    return sorted.isNotEmpty ? sorted : recognizedAppNames.take(8).toList();
  }

  // Top Payees / Senders (Who money was paid to most often or highest sum)
  List<PayeeSummary> get topPaidSenders {
    final expenses = _allTransactions.where((t) => !t.isCredit).toList();
    if (expenses.isEmpty) return [];

    final total = expenses.fold<double>(0.0, (s, t) => s + t.amount);
    final mapTotals = <String, double>{};
    final mapCounts = <String, int>{};

    for (final t in expenses) {
      final name = _cleanPayeeName(t.description);
      mapTotals[name] = (mapTotals[name] ?? 0.0) + t.amount;
      mapCounts[name] = (mapCounts[name] ?? 0) + 1;
    }

    final sorted = mapTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(15).map((e) {
      return PayeeSummary(
        name: e.key,
        totalAmount: e.value,
        count: mapCounts[e.key] ?? 1,
        percentage: total > 0 ? (e.value / total) * 100 : 0.0,
      );
    }).toList();
  }

  List<String> get availablePayees {
    return topPaidSenders.map((p) => p.name).toList();
  }

  // Initialize and load transactions
  Future<void> initialize() async {
    await loadTransactions();
    _startSmsListener();
    syncFromSMS(limit: 50);
  }

  void _startSmsListener() {
    _smsService.listenForNewSMS().listen((sms) async {
      try {
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
        final exists = await _repository.transactionExists(body);
        if (!exists) {
          TransactionModel? transaction;
          try {
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
          } catch (_) {}
          if (transaction == null) {
            transaction = _parserService.parseSMS(
              smsBody: body,
              sender: sender,
              receivedDate: date,
            );
          }
          if (transaction != null) {
            await _repository.addTransaction(transaction);
            await _notificationService.showTransactionNotification(transaction);
            await loadTransactions();
          }
        }
      } catch (e) {
        /* SMS listener error ignored */
      }
    });
  }

  
  Future<void> loadTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allTransactions = await _repository.getAllTransactions();
      _allOtps = List<OtpModel>.from(_smsService.cachedOtps);
      _applyFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncFromSMS({int? limit}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      final smsList = await _smsService.readExistingSMS(limit: limit);
      _allOtps = List<OtpModel>.from(_smsService.cachedOtps);

      final newTransactions = <TransactionModel>[];
      for (final sms in smsList) {
        final exists = await _repository.transactionExists(sms['body']);
        if (exists) continue;

        TransactionModel? transaction;
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
        } catch (_) {}

        if (transaction == null) {
          transaction = _parserService.parseSMS(
            smsBody: sms['body'],
            sender: sms['sender'],
            receivedDate: sms['date'],
          );
        }

        if (transaction != null) {
          newTransactions.add(transaction);
        }
      }

      if (newTransactions.isNotEmpty) {
        await _repository.addTransactions(newTransactions);
        await loadTransactions();
      }

      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    try {
      await _repository.addTransaction(transaction);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    try {
      await _repository.updateTransaction(transaction);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _repository.deleteTransaction(id);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void setDateRange(DateRangeType type, {DateTime? start, DateTime? end}) {
    _dateRangeType = type;
    if (type == DateRangeType.custom) {
      _customStartDate = start;
      _customEndDate = end;
    }
    _applyFilters();
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void setBankFilter(String? bankName) {
    _selectedBank = bankName;
    _applyFilters();
    notifyListeners();
  }

  void setAppFilter(String? app) {
    _selectedApp = app;
    _applyFilters();
    notifyListeners();
  }

  void setPayeeFilter(String? payee) {
    _selectedPayee = payee;
    _applyFilters();
    notifyListeners();
  }

  void setYearFilter(int? year) {
    _selectedYear = year;
    _applyFilters();
    notifyListeners();
  }

  void setOnlyWastedFilter(bool value) {
    _onlyWastedSpends = value;
    _applyFilters();
    notifyListeners();
  }

  void setTypeFilter(bool? isCredit) {
    _selectedType = isCredit;
    _applyFilters();
    notifyListeners();
  }

  void setOtpServiceFilter(String? service) {
    _selectedOtpService = service;
    notifyListeners();
  }

  void setOtpSenderFilter(String? sender) {
    _selectedOtpSender = sender;
    notifyListeners();
  }

  void clearOtpFilters() {
    _selectedOtpService = null;
    _selectedOtpSender = null;
    notifyListeners();
  }

  void clearFilters() {
    _dateRangeType = DateRangeType.all;
    _selectedCategory = null;
    _selectedBank = null;
    _selectedApp = null;
    _selectedPayee = null;
    _selectedYear = null;
    _selectedType = null;
    _onlyWastedSpends = false;
    _customStartDate = null;
    _customEndDate = null;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    var filtered = List<TransactionModel>.from(_allTransactions);

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

    if (_selectedYear != null) {
      filtered = filtered.where((t) => t.dateTime.year == _selectedYear).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((t) => t.category == _selectedCategory).toList();
    }

    if (_selectedBank != null) {
      filtered = filtered.where((t) => t.bankName == _selectedBank).toList();
    }

    if (_selectedApp != null) {
      filtered = filtered.where((t) {
        final app = _identifyCorporateApp(t.description);
        return app != null && app.toLowerCase() == _selectedApp!.toLowerCase();
      }).toList();
    }

    if (_selectedPayee != null) {
      filtered = filtered.where((t) {
        final payee = _cleanPayeeName(t.description);
        return payee.toLowerCase() == _selectedPayee!.toLowerCase();
      }).toList();
    }

    if (_onlyWastedSpends) {
      filtered = filtered.where((t) => !t.isCredit && t.isUselessSpend()).toList();
    }

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

  // Filter ONLY legitimate consumer apps and merchants
  static String? _identifyCorporateApp(String raw) {
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
    if (lower.contains('prime video') || lower.contains('amazon prime')) return 'Prime Video';
    if (lower.contains('hotstar')) return 'Hotstar';
    if (lower.contains('bigbasket')) return 'BigBasket';
    if (lower.contains('dmart')) return 'DMart';
    if (lower.contains('paytm')) return 'Paytm';
    if (lower.contains('phonepe')) return 'PhonePe';
    if (lower.contains('google pay') || lower.contains('gpay')) return 'Google Pay';
    if (lower.contains('cred')) return 'Cred';
    if (lower.contains('irctc')) return 'IRCTC';
    if (lower.contains('makemytrip')) return 'MakeMyTrip';
    if (lower.contains('bookmyshow')) return 'BookMyShow';
    if (lower.contains('dominos') || lower.contains('domino\'s')) return 'Dominos';
    if (lower.contains('mcdonald')) return 'McDonalds';
    if (lower.contains('starbucks')) return 'Starbucks';
    if (lower.contains('kfc')) return 'KFC';
    if (lower.contains('pizza hut')) return 'Pizza Hut';
    if (lower.contains('apollo')) return 'Apollo Pharmacy';
    if (lower.contains('pharmeasy')) return 'PharmEasy';
    if (lower.contains('netmeds')) return 'Netmeds';
    if (lower.contains('1mg')) return 'Tata 1mg';
    if (lower.contains('zerodha')) return 'Zerodha';
    if (lower.contains('groww')) return 'Groww';
    if (lower.contains('upstox')) return 'Upstox';
    if (lower.contains('airtel')) return 'Airtel';
    if (lower.contains('jio')) return 'Jio';
    if (lower.contains('vodafone') || lower.contains('vi ')) return 'Vodafone';
    return null;
  }

  // Extract clean Payee / Receiver name (strips raw UPI addresses like user@okaxis)
  static String _cleanPayeeName(String raw) {
    final app = _identifyCorporateApp(raw);
    if (app != null) return app;

    var text = raw.trim();
    if (text.contains('@')) {
      final handle = text.split('@').first;
      text = handle.split('.').first;
    }

    text = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ').trim();
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    final bankingTerms = {
      'upi', 'vpa', 'imps', 'neft', 'rtgs', 'txn', 'transfer', 'ac', 'a c',
      'ref', 'reference', 'bank', 'payment', 'inr', 'rs', 'debited', 'credited',
      'sent', 'paid', 'account', 'card', 'pos', 'atm', 'nach', 'ecs'
    };

    final words = text.split(' ').where((w) => !bankingTerms.contains(w.toLowerCase()) && w.length > 1).toList();
    if (words.isEmpty) return 'Other Payee';

    return words.take(2).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  void dispose() {
    _smsService.dispose();
    super.dispose();
  }
}
