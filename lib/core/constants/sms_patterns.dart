class SmsPatterns {
  // Common amount patterns
  static final List<RegExp> amountPatterns = [
    // Rs. 1,234.56 or Rs.1234.56 or Rs 1234.56
    RegExp(r'Rs\.?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)', caseSensitive: false),
    // INR 1,234.56 or INR1234.56
    RegExp(r'INR\.?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)', caseSensitive: false),
    // ₹1,234.56 or ₹ 1234.56
    RegExp(r'₹\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)', caseSensitive: false),
    // 1234.56 rupees / INR / Rs
    RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)\s*(?:INR|Rs\.?|rupees)', caseSensitive: false),
  ];

  // Debit/Expense Keywords
  static final List<String> debitKeywords = [
    'debited',
    'debit',
    'spent',
    'withdrawn',
    'withdrawal',
    'paid',
    'payment',
    'purchase',
    'charged',
    'deducted',
    'used',
    'sent',
    'transferred',
    'debited from',
    'deducted from',
  ];

  // Credit/Income Keywords
  static final List<String> creditKeywords = [
    'credited',
    'credit',
    'received',
    'deposited',
    'deposit',
    'refund',
    'cashback',
    'salary',
    'income',
    'added',
    'transferred to',
    'credited to',
    'received in',
  ];

  // Transaction Type Patterns
  static final Map<String, List<RegExp>> transactionPatterns = {
    'debit_card': [
      RegExp(r'spent.*card.*(\d+)', caseSensitive: false),
      RegExp(r'card.*(\d+).*debited', caseSensitive: false),
      RegExp(r'purchase.*card', caseSensitive: false),
    ],
    'upi': [
      RegExp(r'upi.*transaction', caseSensitive: false),
      RegExp(r'paid.*via.*upi', caseSensitive: false),
      RegExp(r'upi.*ref.*no', caseSensitive: false),
      RegExp(r'@\w+', caseSensitive: false), // UPI ID pattern
    ],
    'atm': [
      RegExp(r'atm.*withdrawal', caseSensitive: false),
      RegExp(r'cash.*withdrawn.*atm', caseSensitive: false),
    ],
    'pos': [
      RegExp(r'pos.*purchase', caseSensitive: false),
      RegExp(r'swiped.*at', caseSensitive: false),
    ],
    'neft': [
      RegExp(r'neft', caseSensitive: false),
      RegExp(r'imps', caseSensitive: false),
      RegExp(r'rtgs', caseSensitive: false),
    ],
  };

  // Bank-specific patterns
  static final Map<String, List<RegExp>> bankPatterns = {
    'SBI': [
      RegExp(r'sbi', caseSensitive: false),
      RegExp(r'state bank', caseSensitive: false),
      RegExp(r'sbipay', caseSensitive: false),
    ],
    'HDFC': [
      RegExp(r'hdfc', caseSensitive: false),
      RegExp(r'hdfcbank', caseSensitive: false),
    ],
    'ICICI': [
      RegExp(r'icici', caseSensitive: false),
      RegExp(r'icicib', caseSensitive: false),
    ],
    'Axis': [
      RegExp(r'axis', caseSensitive: false),
      RegExp(r'axisbank', caseSensitive: false),
    ],
    'Kotak': [
      RegExp(r'kotak', caseSensitive: false),
    ],
    'PNB': [
      RegExp(r'pnb', caseSensitive: false),
      RegExp(r'punjab national', caseSensitive: false),
    ],
    'Paytm': [
      RegExp(r'paytm', caseSensitive: false),
    ],
    'PhonePe': [
      RegExp(r'phonepe', caseSensitive: false),
    ],
    'GooglePay': [
      RegExp(r'google.*pay', caseSensitive: false),
      RegExp(r'gpay', caseSensitive: false),
    ],
  };

  // Account number pattern
  static final RegExp accountPattern = RegExp(
    r'a/c.*?(\d{4,})|account.*?(\d{4,})|XX+(\d{4})',
    caseSensitive: false,
  );

  // Date patterns
  static final List<RegExp> datePatterns = [
    // DD-MM-YYYY or DD/MM/YYYY
    RegExp(r'(\d{2})[-/](\d{2})[-/](\d{4})'),
    // DD-MM-YY or DD/MM/YY
    RegExp(r'(\d{2})[-/](\d{2})[-/](\d{2})'),
    // Month DD, YYYY
    RegExp(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{1,2}),?\s+(\d{4})', caseSensitive: false),
  ];

  // Time patterns
  static final RegExp timePattern = RegExp(
    r'(\d{1,2}):(\d{2})\s*(am|pm)?',
    caseSensitive: false,
  );

  // Merchant/Description extraction patterns
  static final List<RegExp> merchantPatterns = [
    // "at MERCHANT_NAME"
    RegExp(r'at\s+([A-Z][A-Za-z0-9\s&.-]+?)(?:\s+on|\s+dated|\s+\d|\.|$)', caseSensitive: false),
    // "to MERCHANT_NAME"
    RegExp(r'to\s+([A-Z][A-Za-z0-9\s&.-]+?)(?:\s+on|\s+dated|\s+\d|\.|$)', caseSensitive: false),
    // "on MERCHANT_NAME"
    RegExp(r'on\s+([A-Z][A-Za-z0-9\s&.-]+?)(?:\s+dated|\s+\d|\.|$)', caseSensitive: false),
  ];

  // Helper method to check if SMS is a transaction SMS
  static bool isTransactionSMS(String sms) {
    final lowerSms = sms.toLowerCase();

    // Fast-fail OTP messages
    if (lowerSms.contains('otp') ||
        lowerSms.contains('verification code') ||
        lowerSms.contains('one time password') ||
        lowerSms.contains('auth code')) {
      return false;
    }

    // Check for debit or credit keywords
    final hasDebitKeyword = debitKeywords.any((keyword) => lowerSms.contains(keyword));
    final hasCreditKeyword = creditKeywords.any((keyword) => lowerSms.contains(keyword));

    // Check for explicit currency pattern or currency symbol
    final hasAmount = amountPatterns.any((pattern) => pattern.hasMatch(sms)) ||
        RegExp(r'(?:Rs\.?|INR|₹|\brupees\b)', caseSensitive: false).hasMatch(sms);

    return (hasDebitKeyword || hasCreditKeyword) && hasAmount;
  }

  // Helper method to check if sender is a bank/financial service
  static bool isBankSender(String sender) {
    final lowerSender = sender.toLowerCase();
    
    // Common bank sender patterns (keywords)
    final bankKeywords = [
      'bank',
      'card',
      'upi',
      'wallet',
      'paytm',
      'phonepe',
      'gpay',
      'bhim',
      'sbi',
      'hdfc',
      'icici',
      'axis',
      'kotak',
      'pnb',
      'bob',
      'canara',
      'union',
      'idbi',
      'yes',
      'indus',
      'federal',
      'rbl',
      'citi',
      'hsbc',
      'sc', // Standard Chartered
      'dbs',
      'baroda',
      'indian',
      'central',
      'vijaya',
      'dena',
      'andhra',
      'allahabad',
      'corporation',
      'oriental',
      'syndicate',
      'uco',
      'united',
      'karnataka',
      'maharashtra',
      'punjab',
      'rajasthan',
      'tmb', // Tamilnad Mercantile Bank
      'kvb', // Karur Vysya Bank
      'dcb', // DCB Bank
      'jammu',
      'kashmir',
    ];
    
    // Check for bank keywords
    if (bankKeywords.any((keyword) => lowerSender.contains(keyword))) {
      return true;
    }
    
    // Check for common alphanumeric sender ID patterns
    // Format: XX-BANKNAME or VM-BANKNAME or AD-BANKNAME
    final alphanumericPattern = RegExp(r'^[A-Z]{2}-[A-Z]+$', caseSensitive: false);
    if (alphanumericPattern.hasMatch(sender)) {
      return true;
    }
    
    // Check for sender IDs that start with common prefixes
    final prefixes = ['vm-', 'ad-', 'ax-', 'tm-', 'bp-', 'tx-', 'bk-'];
    if (prefixes.any((prefix) => lowerSender.startsWith(prefix))) {
      return true;
    }
    
    // Check for 6-character alphanumeric codes (common for banks)
    final sixCharPattern = RegExp(r'^[A-Z0-9]{6}$', caseSensitive: false);
    if (sixCharPattern.hasMatch(sender)) {
      // Additional check: should contain at least one letter
      if (RegExp(r'[A-Z]', caseSensitive: false).hasMatch(sender)) {
        return true;
      }
    }
    
    return false;
  }

  // Helper to extract clean amount (remove commas)
  static double? parseAmount(String amountStr) {
    try {
      // Remove commas and parse
      final cleanAmount = amountStr.replaceAll(',', '');
      return double.parse(cleanAmount);
    } catch (e) {
      return null;
    }
  }
}
