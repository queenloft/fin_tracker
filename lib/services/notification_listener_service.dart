import 'dart:async';
import '../data/models/transaction_model.dart';
import '../data/repositories/transaction_repository.dart';
import 'parser_service.dart';
import 'categorization_service.dart';

class ServiceNotificationEvent {
  final String? packageName;
  final String? title;
  final String? content;
  final DateTime? createAt;
  ServiceNotificationEvent({this.packageName, this.title, this.content, this.createAt});
}

class SystemNotificationListenerService {
  static Future<bool> isPermissionGranted() async => false;
  static Future<bool> requestPermission() async => false;
  static Stream<ServiceNotificationEvent> get notificationsStream => const Stream.empty();
}

class NotificationListenerService {
  final TransactionRepository _repository = TransactionRepository();
  final ParserService _parserService = ParserService();
  final CategorizationService _categorizationService = CategorizationService();
  
  bool _isListening = false;
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  
  // Payment app package names to monitor
  static const List<String> paymentAppPackages = [
    // UPI Apps
    'com.google.android.apps.nbu.paisa.user', // Google Pay
    'com.phonepe.app', // PhonePe
    'net.one97.paytm', // Paytm
    'in.org.npci.upiapp', // BHIM
    
    // Banks
    'com.snapwork.hdfc', // HDFC Bank
    'com.csam.icici.bank.imobile', // ICICI iMobile
    'com.sbi.lotusintouch', // SBI YONO
    'com.axis.mobile', // Axis Mobile
    'com.msf.kbank.mobile', // Kotak
    'com.infrasofttech.pnbpsp', // PNB
    'com.bankofbaroda.mconnect', // BOB
    
    // Wallets
    'in.amazon.mShop.android.shopping', // Amazon Pay
    'com.mobikwik_new', // Mobikwik
    'com.freecharge.android', // Freecharge
  ];
  
  // Start listening to notifications
  Future<bool> startListening() async {
    try {
      // Check if permission is granted
      final hasPermission = await SystemNotificationListenerService.isPermissionGranted();
      
      if (!hasPermission) {
        return false;
      }
      
      // Start listening
      _subscription = SystemNotificationListenerService.notificationsStream.listen((event) {
        _handleNotification(event);
      });
      
      _isListening = true;
      return true;
    } catch (e) {
      print('Error starting notification listener: $e');
      return false;
    }
  }
  
  // Stop listening
  void stopListening() {
    _isListening = false;
  }
  
  // Check if currently listening
  bool get isListening => _isListening;
  
  // Handle incoming notification
  void _handleNotification(ServiceNotificationEvent event) async {
    try {
      final packageName = event.packageName ?? '';
      final title = event.title ?? '';
      final content = event.content ?? '';
      
      // Check if it's from a payment app
      if (!_isPaymentApp(packageName)) {
        return;
      }
      
      print('Payment notification from $packageName: $title - $content');
      
      // Parse notification text
      final transaction = _parseNotification(
        packageName: packageName,
        title: title,
        text: content,
        timestamp: DateTime.now(),
      );
      
      if (transaction != null) {
        // Check if transaction already exists
        final exists = await _repository.transactionExists(content);
        if (!exists) {
          // Save transaction
          await _repository.addTransaction(transaction);
          print('Transaction saved from notification: ${transaction.description}');
        }
      }
    } catch (e) {
      print('Error handling notification: $e');
    }
  }
  
  // Check if package is a payment app
  bool _isPaymentApp(String packageName) {
    return paymentAppPackages.any((pkg) => packageName.contains(pkg));
  }
  
  // Parse notification text to extract transaction details
  TransactionModel? _parseNotification({
    required String packageName,
    required String title,
    required String text,
    required DateTime timestamp,
  }) {
    final fullText = '$title $text';
    
    // Extract amount
    final amount = _extractAmount(fullText);
    if (amount == null || amount <= 0) {
      return null;
    }
    
    // Determine if credit or debit
    final isCredit = _isCredit(fullText);
    
    // Extract merchant/description
    final description = _extractDescription(fullText);
    
    // Detect app name
    final appName = _detectApp(packageName);
    
    // Auto-categorize
    final category = _categorizationService.categorizeTransaction(
      description: description,
      merchant: description,
      isCredit: isCredit,
    );
    
    return TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: timestamp,
      amount: amount,
      isCredit: isCredit,
      category: category,
      description: description,
      bankName: appName,
      rawSms: fullText,
    );
  }
  
  // Extract amount from notification text
  double? _extractAmount(String text) {
    // Common patterns: ₹500, Rs.500, Rs 500, INR 500
    final patterns = [
      RegExp(r'₹\s*(\d{1,}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'Rs\.?\s*(\d{1,}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
      RegExp(r'INR\.?\s*(\d{1,}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          return double.tryParse(amountStr);
        }
      }
    }
    
    return null;
  }
  
  // Determine if transaction is credit or debit
  bool _isCredit(String text) {
    final lowerText = text.toLowerCase();
    
    // Credit keywords
    const creditKeywords = [
      'credited',
      'received',
      'deposited',
      'refund',
      'cashback',
      'added',
    ];
    
    // Debit keywords
    const debitKeywords = [
      'debited',
      'paid',
      'sent',
      'withdrawn',
      'spent',
      'charged',
    ];
    
    final hasCredit = creditKeywords.any((k) => lowerText.contains(k));
    final hasDebit = debitKeywords.any((k) => lowerText.contains(k));
    
    if (hasCredit && !hasDebit) return true;
    if (hasDebit && !hasCredit) return false;
    
    // Default to debit
    return false;
  }
  
  // Extract merchant/description
  String _extractDescription(String text) {
    // Try to extract merchant name after common patterns
    final patterns = [
      RegExp(r'(?:at|to|from)\s+([A-Za-z0-9\s&.-]+?)(?:\s+on|\s+via|\s+using|$)', caseSensitive: false),
      RegExp(r'(?:paid|sent)\s+to\s+([A-Za-z0-9\s&.-]+?)(?:\s+via|$)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.isNotEmpty) {
          return merchant.substring(0, merchant.length > 50 ? 50 : merchant.length);
        }
      }
    }
    
    // Fallback: use first few words
    final words = text.split(' ').where((w) => w.length > 2).take(5);
    return words.isEmpty ? 'Transaction' : words.join(' ');
  }
  
  // Detect app name from package
  String _detectApp(String packageName) {
    if (packageName.contains('google')) return 'Google Pay';
    if (packageName.contains('phonepe')) return 'PhonePe';
    if (packageName.contains('paytm')) return 'Paytm';
    if (packageName.contains('bhim')) return 'BHIM';
    if (packageName.contains('hdfc')) return 'HDFC Bank';
    if (packageName.contains('icici')) return 'ICICI Bank';
    if (packageName.contains('sbi')) return 'SBI';
    if (packageName.contains('axis')) return 'Axis Bank';
    if (packageName.contains('kotak')) return 'Kotak';
    if (packageName.contains('pnb')) return 'PNB';
    if (packageName.contains('baroda')) return 'Bank of Baroda';
    if (packageName.contains('amazon')) return 'Amazon Pay';
    if (packageName.contains('mobikwik')) return 'Mobikwik';
    if (packageName.contains('freecharge')) return 'Freecharge';
    
    return 'Payment App';
  }
  
  // Dispose resources
  void dispose() {
    stopListening();
  }
}
