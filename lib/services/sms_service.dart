import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';
import '../core/constants/sms_patterns.dart';
import 'gemini_service.dart';
import '../data/models/otp_model.dart';

class SmsService {
  final Telephony telephony = Telephony.instance;
  final GeminiService _geminiService = GeminiService();
  StreamController<Map<String, dynamic>>? _smsStreamController;
  
  // Debug statistics
  int _totalSmsRead = 0;
  int _bankSenderFiltered = 0;
  int _transactionFiltered = 0;
  int _otpFiltered = 0;
  int _finalBankSms = 0;
  final List<Map<String, String>> _filteredOutSamples = [];
  final List<String> _debugLogs = [];
  final List<OtpModel> _cachedOtps = [];

  List<OtpModel> get cachedOtps => List.unmodifiable(_cachedOtps);

  // Debug getters
  int get totalSmsRead => _totalSmsRead;
  int get bankSenderFiltered => _bankSenderFiltered;
  int get transactionFiltered => _transactionFiltered;
  int get otpFiltered => _otpFiltered;
  int get finalBankSms => _finalBankSms;
  List<Map<String, String>> get filteredOutSamples => _filteredOutSamples;
  List<String> get debugLogs => _debugLogs;
  
  // Reset debug statistics
  void resetDebugStats() {
    _totalSmsRead = 0;
    _bankSenderFiltered = 0;
    _transactionFiltered = 0;
    _otpFiltered = 0;
    _finalBankSms = 0;
    _filteredOutSamples.clear();
    _debugLogs.clear();
  }
  
  void _addDebugLog(String message) {
    _debugLogs.add('[${DateTime.now().toIso8601String()}] $message');
    print('SMS_DEBUG: $message');
  }

  // Parse SMS using AI
  Future<Map<String, dynamic>?> parseSmsWithAi(String body) async {
    return await _geminiService.parseSms(body);
  }

  // Request SMS permissions
  Future<bool> requestPermissions() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  // Check if SMS permissions are granted
  Future<bool> hasPermissions() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  // Read existing SMS from inbox
  Future<List<Map<String, dynamic>>> readExistingSMS({
    int? limit,
    DateTime? since,
  }) async {
    try {
      resetDebugStats();
      _addDebugLog('Starting SMS read...');
      
      final hasPermission = await hasPermissions();
      if (!hasPermission) {
        _addDebugLog('ERROR: SMS permission not granted');
        throw Exception('SMS permission not granted');
      }
      
      _addDebugLog('SMS permission granted, reading messages...');

      // Try reading SMS with different approaches
      List<SmsMessage> messages = [];
      
      try {
        // Try reading from Inbox
        _addDebugLog('Attempting to read from INBOX...');
        messages = await telephony.getInboxSms(
          columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
          sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
        );
        _addDebugLog('Inbox SMS count: ${messages.length}');
      } catch (e) {
        _addDebugLog('ERROR reading Inbox: $e');
      }
      
      // If inbox is empty, try without specifying columns
      if (messages.isEmpty) {
        try {
          _addDebugLog('Inbox empty, trying without column filter...');
          messages = await telephony.getInboxSms();
          _addDebugLog('Unfiltered Inbox SMS count: ${messages.length}');
        } catch (e) {
          _addDebugLog('ERROR reading unfiltered Inbox: $e');
        }
      }
      
      // Try Sent folder as last resort
      if (messages.isEmpty) {
        try {
          _addDebugLog('Still empty, trying SENT folder...');
          final sentMessages = await telephony.getSentSms(
            columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
            sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
          );
          _addDebugLog('Sent SMS count: ${sentMessages.length}');
          // Note: We don't use sent messages for transactions, just for diagnostics
        } catch (e) {
          _addDebugLog('ERROR reading Sent SMS: $e');
        }
      }
      
      _totalSmsRead = messages.length;
      _addDebugLog('Total SMS read from device: $_totalSmsRead');
      
      if (_totalSmsRead == 0) {
        _addDebugLog('WARNING: No SMS found on device. Possible causes:');
        _addDebugLog('  1. Device has no SMS messages in Inbox');
        _addDebugLog('  2. SMS permission not fully granted (check Settings > Apps > FinTracker > Permissions)');
        _addDebugLog('  3. Device-specific telephony API issue');
        _addDebugLog('  4. SMS app restrictions (some Android versions restrict non-default SMS apps)');
        _addDebugLog('  5. Try granting "Default SMS app" permission temporarily');
      }

      final bankSms = <Map<String, dynamic>>[];
      int dateFiltered = 0;

      for (final message in messages) {
        final sender = message.address ?? '';
        final body = message.body ?? '';
        
        // Log first few messages for debugging
        if (bankSms.isEmpty && _totalSmsRead > 0 && _totalSmsRead <= 3) {
          _addDebugLog('Sample SMS - Sender: $sender, Body: ${body.substring(0, body.length > 50 ? 50 : body.length)}...');
        }
        
        // Filter by date if specified
        if (since != null) {
          final messageDate = DateTime.fromMillisecondsSinceEpoch(
            message.date ?? 0,
          );
          if (messageDate.isBefore(since)) {
            dateFiltered++;
            continue;
          }
        }

        // Check bank sender first
        if (!SmsPatterns.isBankSender(sender)) {
          _bankSenderFiltered++;
          continue;
        }
        
        // Check if it's a transaction SMS
        if (!SmsPatterns.isTransactionSMS(body)) {
          _transactionFiltered++;
          // Save sample for debugging (max 10)
          if (_filteredOutSamples.length < 10) {
            _filteredOutSamples.add({
              'sender': sender,
              'body': body.substring(0, body.length > 100 ? 100 : body.length),
              'reason': 'No transaction keywords or amount found',
            });
          }
          continue;
        }
        
        // Check if it's an OTP
        if (_isOTP(body)) {
          _otpFiltered++;
          // Save sample for debugging (max 10)
          if (_filteredOutSamples.length < 10) {
            _filteredOutSamples.add({
              'sender': sender,
              'body': body.substring(0, body.length > 100 ? 100 : body.length),
              'reason': 'Detected as OTP',
            });
          }
          continue;
        }

        // This is a valid bank transaction SMS
        _finalBankSms++;
        bankSms.add({
          'sender': sender,
          'body': body,
          'date': DateTime.fromMillisecondsSinceEpoch(message.date ?? 0),
        });

        // Limit results if specified
        if (limit != null && bankSms.length >= limit) {
          _addDebugLog('Reached limit of $limit messages');
          break;
        }
      }
      
      _addDebugLog('Filtering complete:');
      _addDebugLog('  - Date filtered: $dateFiltered');
      _addDebugLog('  - Non-bank sender: $_bankSenderFiltered');
      _addDebugLog('  - No transaction keywords: $_transactionFiltered');
      _addDebugLog('  - OTP filtered: $_otpFiltered');
      _addDebugLog('  - Final bank SMS: $_finalBankSms');

      return bankSms;
    } catch (e) {
      _addDebugLog('ERROR: Failed to read SMS: $e');
      throw Exception('Failed to read SMS: $e');
    }
  }

  // Listen for new incoming SMS
  Stream<Map<String, dynamic>> listenForNewSMS() {
    _smsStreamController = StreamController<Map<String, dynamic>>.broadcast();

    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        final sender = message.address ?? '';
        final body = message.body ?? '';
        final date = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);

        // Only emit bank/transaction SMS
        if (_isBankSMS(sender, body)) {
          _smsStreamController?.add({
            'sender': sender,
            'body': body,
            'date': date,
          });
        }
      },
      listenInBackground: false,
    );

    return _smsStreamController!.stream;
  }

  // Stop listening for SMS
  void stopListening() {
    _smsStreamController?.close();
    _smsStreamController = null;
  }

  // Extract OTP details from SMS
  OtpModel? extractOtpDetails(String sender, String body, DateTime date) {
    final lower = body.toLowerCase();
    
    // Pattern match 4 to 8 digit OTP
    final patterns = [
      RegExp(r'(?:otp|code|verification code|is|password)[\s:]*([0-9]{4,8})\b', caseSensitive: false),
      RegExp(r'\b([0-9]{4,8})[\s]*(?:is your|as your|for your|otp|code)', caseSensitive: false),
      RegExp(r'\b([0-9]{4,6})\b'),
    ];

    String? code;
    for (final p in patterns) {
      final match = p.firstMatch(body);
      if (match != null) {
        code = match.group(1);
        if (code != null && code.length >= 4 && code.length <= 8) break;
      }
    }

    if (code == null) return null;

    // Detect service name
    String service = 'Verification';
    if (lower.contains('amazon')) service = 'Amazon';
    else if (lower.contains('swiggy')) service = 'Swiggy';
    else if (lower.contains('zomato')) service = 'Zomato';
    else if (lower.contains('flipkart')) service = 'Flipkart';
    else if (lower.contains('google')) service = 'Google';
    else if (lower.contains('whatsapp')) service = 'WhatsApp';
    else if (lower.contains('paytm')) service = 'Paytm';
    else if (lower.contains('phonepe')) service = 'PhonePe';
    else if (lower.contains('hdfc')) service = 'HDFC Bank';
    else if (lower.contains('sbi')) service = 'SBI Bank';
    else if (lower.contains('icici')) service = 'ICICI Bank';
    else if (lower.contains('axis')) service = 'Axis Bank';
    else if (lower.contains('kotak')) service = 'Kotak Bank';
    else if (lower.contains('uber')) service = 'Uber';
    else if (lower.contains('ola')) service = 'Ola';
    else if (lower.contains('irctc')) service = 'IRCTC';
    else if (lower.contains('blinkit')) service = 'Blinkit';
    else if (lower.contains('zepto')) service = 'Zepto';
    else if (sender.isNotEmpty) {
      service = sender.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    }

    return OtpModel(
      id: '${date.millisecondsSinceEpoch}_$code',
      sender: sender,
      code: code,
      body: body,
      dateTime: date,
      serviceName: service,
    );
  }

  // Filter bank/transactional SMS
  bool _isBankSMS(String sender, String body) {
    // Check if sender is a bank
    if (!SmsPatterns.isBankSender(sender)) {
      return false;
    }

    // Check if it's a transaction SMS (not OTP or promotional)
    if (!SmsPatterns.isTransactionSMS(body)) {
      return false;
    }

    // Filter out OTP messages
    if (_isOTP(body)) {
      return false;
    }

    return true;
  }

  // Check if SMS is an OTP
  bool _isOTP(String body) {
    final lowerBody = body.toLowerCase();
    
    // Common OTP keywords - need at least one
    const otpKeywords = [
      'otp',
      'one time password',
      'verification code',
      'authentication code',
    ];
    
    bool hasOtpKeyword = false;
    for (final keyword in otpKeywords) {
      if (lowerBody.contains(keyword)) {
        hasOtpKeyword = true;
        break;
      }
    }
    
    // If it has explicit OTP keywords, it's definitely an OTP
    if (hasOtpKeyword) {
      return true;
    }
    
    // Check for 'verify' keyword - but only if message is short and has a single number
    if (lowerBody.contains('verify')) {
      final otpPattern = RegExp(r'\b\d{4,6}\b');
      final matches = otpPattern.allMatches(body);
      // If there's only one number and it's 4-6 digits, likely an OTP
      if (matches.length == 1 && body.length < 100) {
        return true;
      }
    }
    
    // Don't filter based on just having a 4-6 digit number
    // Many transaction SMS have reference numbers
    return false;
  }

  // Get SMS count
  Future<int> getSmsCount() async {
    try {
      final messages = await readExistingSMS();
      return messages.length;
    } catch (e) {
      return 0;
    }
  }

  // Dispose resources
  void dispose() {
    stopListening();
  }
}
