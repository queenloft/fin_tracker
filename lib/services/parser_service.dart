import 'package:uuid/uuid.dart';
import '../data/models/transaction_model.dart';
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
    // Check if it's a transaction SMS
    if (!SmsPatterns.isTransactionSMS(smsBody)) {
      return null;
    }
    // Exclude non-transaction alerts such as EMI offers or service alerts
    final lower = smsBody.toLowerCase();
    if (lower.contains('dues of') ||
        lower.contains('can be converted into emis') ||
        lower.contains('converted into emis') ||
        lower.contains('service alert') ||
        lower.contains('emi offer') ||
        lower.contains('emi') ||
        lower.contains('based on') ||
        lower.contains('outstanding') ||
        lower.contains('complete') ||
        lower.contains('due:') ||
        lower.contains('due ') ||
        lower.contains('maintenance') ||
        lower.contains('reflects') ||
        lower.contains('loan') ||
        lower.contains('statement') ||
        lower.contains('emi') ||
        lower.contains('awaiting') ||
        lower.contains('raised') ||
        lower.contains('disputed') ||
        lower.contains('reduced') ||
          lower.contains('amt due:') ||
          lower.contains('reward points') ||
          lower.contains('added') ||
          lower.contains('emi') ||
          lower.contains('disabled') ||
          lower.contains('modified') ||
          lower.contains('pin') ||
          lower.contains('usage') ||
          lower.contains('reset') ||
          lower.contains('avoid') ||
          lower.contains('fees') ||
            lower.contains('missed')


        ) {
      return null;
    }
    // Extract amount
    final amount = _extractAmount(smsBody);
    if (amount == null || amount <= 0) {
      return null;
    }
    // Determine if credit or debit
    final isCredit = _isCredit(smsBody);
    // Extract merchant/description
    final description = _extractDescription(smsBody);
    // Detect bank name
    final bankName = _detectBank(sender);
    // Auto-categorize
    final category = _categorizationService.categorizeTransaction(
      description: description,
      merchant: description,
      isCredit: isCredit,
    );
    // Extract date from SMS (fallback to received date)
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


  // Extract amount from SMS
  double? _extractAmount(String sms) {
    for (final pattern in SmsPatterns.amountPatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        final amountStr = match.group(1);
        if (amountStr != null) {
          return SmsPatterns.parseAmount(amountStr);
        }
      }
    }
    return null;
  }

  // Determine if transaction is credit or debit
  bool _isCredit(String sms) {
    final lowerSms = sms.toLowerCase();

    // Check for credit keywords
    final hasCreditKeyword = SmsPatterns.creditKeywords.any(
      (keyword) => lowerSms.contains(keyword),
    );

    // Check for debit keywords
    final hasDebitKeyword = SmsPatterns.debitKeywords.any(
      (keyword) => lowerSms.contains(keyword),
    );

    // If both or neither, try to infer from context
    if (hasCreditKeyword && !hasDebitKeyword) {
      return true;
    } else if (hasDebitKeyword && !hasCreditKeyword) {
      return false;
    }

    // Default to debit if ambiguous (most SMS are expenses)
    return false;
  }

  // Extract merchant/description from SMS
  String _extractDescription(String sms) {
    // Try merchant patterns
    for (final pattern in SmsPatterns.merchantPatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        final merchant = match.group(1)?.trim();
        if (merchant != null && merchant.isNotEmpty) {
          return _cleanDescription(merchant);
        }
      }
    }

    // Fallback: extract first meaningful phrase
    final words = sms.split(' ');
    final meaningfulWords = <String>[];

    for (final word in words) {
      // Skip common banking terms
      if (_isCommonBankingTerm(word.toLowerCase())) continue;
      
      // Skip numbers and dates
      if (RegExp(r'^\d+$').hasMatch(word)) continue;
      
      meaningfulWords.add(word);
      
      // Take first 5 meaningful words
      if (meaningfulWords.length >= 5) break;
    }

    return meaningfulWords.isEmpty 
        ? 'Transaction' 
        : _cleanDescription(meaningfulWords.join(' '));
  }

  // Clean up description
  String _cleanDescription(String description) {
    final cleaned = description
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s&.-]'), '')
        .trim();
    return cleaned.length > 50 ? cleaned.substring(0, 50) : cleaned;
  }

  // Check if word is a common banking term
  bool _isCommonBankingTerm(String word) {
    const terms = [
      'debited', 'credited', 'account', 'card', 'upi', 'transaction',
      'payment', 'transfer', 'from', 'your', 'has', 'been', 'the',
      'and', 'for', 'with', 'ref', 'no', 'txn', 'id', 'avl', 'bal',
    ];
    return terms.contains(word);
  }

  // Detect bank name from sender
  String _detectBank(String sender) {
    final lowerSender = sender.toLowerCase();

    for (final entry in SmsPatterns.bankPatterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(lowerSender)) {
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
          // Handle DD-MM-YYYY or DD/MM/YYYY
          if (match.groupCount >= 3) {
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            var year = int.parse(match.group(3)!);
            
            // Handle 2-digit year
            if (year < 100) {
              year += 2000;
            }
            
            return DateTime(year, month, day);
          }
        } catch (e) {
          // Continue to next pattern
        }
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
      final amount = (aiResult['amount'] as num).toDouble();
      final isCredit = (aiResult['type'] as String).toLowerCase() == 'credit';
      final category = aiResult['category'] as String? ?? 'Other';
      final description = aiResult['merchant'] as String? ?? 'Transaction';
      final bankName = _detectBank(sender);

      return TransactionModel(
        id: _uuid.v4(),
        dateTime: receivedDate,
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
