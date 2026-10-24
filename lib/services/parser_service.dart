import 'package:uuid/uuid.dart';
import '../data/models/transaction_model.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/sms_patterns.dart';
import 'categorization_service.dart';

class ParserService {
  final CategorizationService _categorizationService = CategorizationService();
  final Uuid _uuid = const Uuid();

  // Main parsing method
  TransactionModel? parseSMS({
    required String smsBody,
    required String sender,
    required DateTime receivedDate,
  }) {
    // 1. Check if it's a transaction SMS
    if (!SmsPatterns.isTransactionSMS(smsBody)) {
      return null;
    }

    // 2. Exclude purely non-transaction marketing or security notices
    final lower = smsBody.toLowerCase();
    if (lower.contains('can be converted into emis') ||
        lower.contains('service alert') ||
        lower.contains('emi offer') ||
        lower.contains('congratulations') ||
        lower.contains('pre-approved') ||
        lower.contains('claim reward') ||
        lower.contains('statement generated') ||
        lower.contains('maintenance alert') ||
        lower.contains('reset your password') ||
        lower.contains('reward points balance')) {
      return null;
    }

    // 3. Extract amount
    final amount = _extractAmount(smsBody);
    if (amount == null || amount <= 0) {
      return null;
    }

    // 4. Determine if credit or debit
    final isCredit = _isCredit(smsBody);

    // 5. Extract merchant/description
    final description = _extractDescription(smsBody);

    // 6. Detect bank name
    final bankName = _detectBank(sender.isNotEmpty ? sender : smsBody);

    // 7. Auto-categorize (now using rawSms for full accuracy)
    final category = _categorizationService.categorizeTransaction(
      description: description,
      merchant: description,
      isCredit: isCredit,
      rawSms: smsBody,
    );

    // 8. Extract date from SMS (fallback to received date)
    final transactionDate = _extractDate(smsBody) ?? receivedDate;

    return TransactionModel(
      id: _uuid.v4(),
      dateTime: transactionDate,
      amount: amount,
      isCredit: isCredit,
      category: category,
      description: description,
      bankName: bankName,
      rawSms: smsBody,
    );
  }

  // Extract amount from SMS, avoiding balance values and account numbers
  double? _extractAmount(String sms) {
    // Priority 1: Patterns with debit/credit context
    // e.g. "debited with Rs 450", "spent Rs. 1,200", "paid INR 250"
    final contextPatterns = [
      RegExp(r'(?:debited|spent|paid|withdrawn|charged|deducted|transferred|sent)\s+(?:for|by|with|of)?\s*(?:Rs\.?|INR|₹)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:credited|received|deposited|refund|salary|cashback)\s+(?:for|by|with|of)?\s*(?:Rs\.?|INR|₹)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:Rs\.?|INR|₹)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)\s+(?:debited|spent|paid|withdrawn|credited|received|deposited)', caseSensitive: false),
    ];

    for (final pattern in contextPatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          final amt = SmsPatterns.parseAmount(amountStr);
          if (amt != null && amt > 0) return amt;
        }
      }
    }

    // Priority 2: Generic currency prefix, but exclude if preceded by "bal", "balance", "limit"
    final regexCurrency = RegExp(r'(?:Rs\.?|INR|₹)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)', caseSensitive: false);
    for (final match in regexCurrency.allMatches(sms)) {
      final start = match.start;
      final prefix = sms.substring(start > 25 ? start - 25 : 0, start).toLowerCase();
      // Skip if this amount is available balance or limit
      if (prefix.contains('bal') ||
          prefix.contains('balance') ||
          prefix.contains('limit') ||
          prefix.contains('available') ||
          prefix.contains('avl')) {
        continue;
      }
      final amountStr = match.group(1);
      if (amountStr != null) {
        final amt = SmsPatterns.parseAmount(amountStr);
        if (amt != null && amt > 0) return amt;
      }
    }

    // Priority 3: Any amount followed by currency keyword
    final postfixRegex = RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)\s*(?:INR|Rs\.?|rupees)', caseSensitive: false);
    final postMatch = postfixRegex.firstMatch(sms);
    if (postMatch != null) {
      final amountStr = postMatch.group(1);
      if (amountStr != null) {
        final amt = SmsPatterns.parseAmount(amountStr);
        if (amt != null && amt > 0) return amt;
      }
    }

    // Fallback: first currency match in text
    final firstMatch = regexCurrency.firstMatch(sms);
    if (firstMatch != null) {
      final amountStr = firstMatch.group(1);
      if (amountStr != null) {
        return SmsPatterns.parseAmount(amountStr);
      }
    }

    return null;
  }

  // Determine if transaction is credit or debit
  bool _isCredit(String sms) {
    final lower = sms.toLowerCase();

    // Specific user account debit phrases (Money leaving user's account)
    if (lower.contains('debited from') ||
        lower.contains('is debited') ||
        lower.contains('has been debited') ||
        lower.contains('was debited') ||
        lower.contains('paid to') ||
        lower.contains('spent on') ||
        lower.contains('withdrawal') ||
        lower.contains('withdrawn from') ||
        lower.contains('purchase of') ||
        lower.contains('purchase at') ||
        lower.contains('transferred to') ||
        lower.contains('sent to')) {
      return false; // Debit
    }

    // Specific user account credit phrases (Money entering user's account)
    if (lower.contains('credited to') ||
        lower.contains('is credited') ||
        lower.contains('has been credited') ||
        lower.contains('was credited') ||
        lower.contains('received from') ||
        lower.contains('deposited to') ||
        lower.contains('refund of') ||
        lower.contains('refund from') ||
        lower.contains('cashback') ||
        lower.contains('salary credited') ||
        lower.contains('added to your')) {
      return true; // Credit
    }

    // Keyword counting with priority
    final debitCount = SmsPatterns.debitKeywords.where((k) => lower.contains(k)).length;
    final creditCount = SmsPatterns.creditKeywords.where((k) => lower.contains(k)).length;

    if (creditCount > debitCount) {
      return true;
    }

    // Default to debit (majority of transactions are expenses)
    return false;
  }

  // Extract merchant/description from SMS
  String _extractDescription(String sms) {
    // 1. Look for UPI VPA (e.g. to swiggy@icici or VPA: user@paytm)
    final vpaMatch = RegExp(r'(?:to|vpa|upi:?)\s*([a-zA-Z0-9.\-_]+@[a-zA-Z0-9]+)', caseSensitive: false).firstMatch(sms);
    if (vpaMatch != null) {
      final vpa = vpaMatch.group(1)!;
      final handle = vpa.split('@').first;
      final cleanHandle = handle.split('.').first;
      if (cleanHandle.length >= 3 && !_isCommonBankingTerm(cleanHandle.toLowerCase())) {
        return _capitalize(cleanHandle);
      }
    }

    // 2. Scan for well-known merchant names in the SMS body
    final commonMerchants = [
      'Swiggy', 'Zomato', 'Blinkit', 'Zepto', 'BigBasket', 'Instamart', 'Uber', 'Ola', 'Rapido',
      'Amazon', 'Flipkart', 'Myntra', 'Ajio', 'Meesho', 'Nykaa', 'Dominos', 'Pizza Hut',
      'McDonalds', 'KFC', 'Starbucks', 'Netflix', 'Spotify', 'Prime Video', 'Hotstar',
      'Airtel', 'Jio', 'Vodafone', 'Tata Power', 'BESCOM', 'Adani', 'Cred', 'Paytm',
      'PhonePe', 'Google Pay', 'BookMyShow', 'PVR', 'Inox', 'IRCTC', 'MakeMyTrip', 'Goibibo',
      'Apollo', '1mg', 'PharmEasy', 'Netmeds', 'Zerodha', 'Groww', 'Upstox', 'DMart'
    ];

    final lower = sms.toLowerCase();
    for (final m in commonMerchants) {
      if (lower.contains(m.toLowerCase())) {
        return m;
      }
    }

    // 3. Try regex patterns "at MERCHANT" / "to MERCHANT" / "for MERCHANT"
    for (final pattern in SmsPatterns.merchantPatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.isNotEmpty && !_isCommonBankingTerm(merchant.toLowerCase())) {
          return _cleanDescription(merchant);
        }
      }
    }

    // 4. Fallback: extract first meaningful non-banking phrase
    final words = sms.split(RegExp(r'\s+'));
    final meaningfulWords = <String>[];

    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (cleanWord.isEmpty) continue;
      if (_isCommonBankingTerm(cleanWord.toLowerCase())) continue;
      if (RegExp(r'^\d+$').hasMatch(cleanWord)) continue;

      meaningfulWords.add(cleanWord);
      if (meaningfulWords.length >= 3) break;
    }

    return meaningfulWords.isEmpty
        ? 'Transaction'
        : _cleanDescription(meaningfulWords.join(' '));
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // Clean up description
  String _cleanDescription(String description) {
    final cleaned = description
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s&.-]'), '')
        .trim();
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  // Check if word is a common banking term
  bool _isCommonBankingTerm(String word) {
    const terms = [
      'debited', 'credited', 'account', 'card', 'upi', 'transaction',
      'payment', 'transfer', 'from', 'your', 'has', 'been', 'the',
      'and', 'for', 'with', 'ref', 'no', 'txn', 'id', 'avl', 'bal',
      'balance', 'ending', 'ac', 'dear', 'customer', 'user', 'bank',
      'vpa', 'inr', 'rs', 'rupees', 'dated', 'via', 'through', 'at',
    ];
    return terms.contains(word);
  }

  // Detect bank name from sender or message
  String _detectBank(String text) {
    final lower = text.toLowerCase();

    for (final entry in SmsPatterns.bankPatterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(lower)) {
          return entry.key;
        }
      }
    }

    return 'Unknown';
  }

  // Extract date from SMS (if available)
  DateTime? _extractDate(String sms) {
    for (final pattern in SmsPatterns.datePatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        try {
          if (match.groupCount >= 3) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            var year = int.parse(match.group(3)!);

            if (year < 100) {
              year += 2000;
            }

            return DateTime(year, month, day);
          }
        } catch (_) {}
      }
    }

    return null;
  }

  // Parse multiple SMS messages
  List<TransactionModel> parseBulkSMS(List<Map<String, dynamic>> smsList) {
    final transactions = <TransactionModel>[];

    for (final sms in smsList) {
      final transaction = parseSMS(
        smsBody: sms['body'] as String,
        sender: sms['sender'] as String,
        receivedDate: sms['date'] as DateTime,
      );

      if (transaction != null) {
        transactions.add(transaction);
      }
    }

    return transactions;
  }

  // Create transaction from AI result
  TransactionModel? createTransactionFromAiResult({
    required Map<String, dynamic> aiResult,
    required String smsBody,
    required String sender,
    required DateTime receivedDate,
  }) {
    try {
      final rawAmount = aiResult['amount'];
      double? amount;
      if (rawAmount is num) {
        amount = rawAmount.toDouble();
      } else if (rawAmount is String) {
        amount = SmsPatterns.parseAmount(rawAmount);
      }

      if (amount == null || amount <= 0) {
        return null;
      }

      final typeStr = (aiResult['type'] ?? 'debit').toString().toLowerCase();
      final isCredit = typeStr == 'credit' || typeStr == 'income';

      var category = (aiResult['category'] ?? '').toString().trim();
      if (!AppConstants.allCategories.contains(category)) {
        category = _categorizationService.categorizeTransaction(
          description: aiResult['merchant']?.toString() ?? '',
          merchant: aiResult['merchant']?.toString() ?? '',
          isCredit: isCredit,
          rawSms: smsBody,
        );
      }

      var description = (aiResult['merchant'] ?? '').toString().trim();
      if (description.isEmpty ||
          description.toLowerCase() == 'unknown' ||
          description.toLowerCase() == 'null' ||
          description.toLowerCase() == 'transaction') {
        description = _extractDescription(smsBody);
      }

      final bankName = _detectBank(sender.isNotEmpty ? sender : smsBody);
      final transactionDate = _extractDate(smsBody) ?? receivedDate;

      return TransactionModel(
        id: _uuid.v4(),
        dateTime: transactionDate,
        amount: amount,
        isCredit: isCredit,
        category: category,
        description: description,
        bankName: bankName,
        rawSms: smsBody,
      );
    } catch (e) {
      print('Error creating transaction from AI result: $e');
      return null;
    }
  }
}
