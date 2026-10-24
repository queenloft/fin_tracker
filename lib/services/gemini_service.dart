import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants/app_constants.dart';

class GeminiService {
  static final GeminiService instance = GeminiService._internal();
  factory GeminiService() => instance;
  GeminiService._internal();

  static const List<String> candidateModels = [
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash-8b',
    'gemini-1.5-pro',
    'gemini-2.5-flash',
    'gemini-flash-latest',
    'gemini-pro',
  ];

  String? _workingModel;
  String? _customApiKey;

  void setApiKey(String? key) {
    _customApiKey = key?.trim();
    _workingModel = null;
  }

  String get activeApiKey {
    if (_customApiKey != null && _customApiKey!.isNotEmpty) {
      return _customApiKey!;
    }
    return AppConstants.geminiApiKey;
  }

  String? get currentWorkingModel => _workingModel;

  // Parse SMS using Gemini AI
  Future<Map<String, dynamic>?> parseSms(String smsBody) async {
    final apiKey = activeApiKey;
    if (apiKey.isEmpty) {
      return null;
    }

    final prompt = '''
You are an expert financial AI assistant for an Indian expense tracker app.
Analyze this bank or financial transaction SMS:
"$smsBody"

Task:
Determine if this is an actual financial debit (expense/payment) or credit (income/deposit/refund) transaction.
If this message is an OTP, verification code, promotional deal/discount, reward points notice, general advice, or service notice without a transaction, return:
{"isTransaction": false}

If this IS a valid transaction, extract:
- "isTransaction": true
- "amount": (number) The exact transaction amount debited or credited (e.g. 450.50). NEVER use available account balance ("Avl Bal", "Bal") as the transaction amount.
- "type": "debit" (for spent, paid, debited, withdrawn, transferred to) OR "credit" (for received, credited, salary, deposited, refund, cashback).
- "category": Pick the SINGLE best category from ONLY this list:
  ["Food Delivery", "Groceries", "Transport", "Online Shopping", "Bills & Utilities", "EMI", "Rent", "Salary", "Entertainment", "Subscriptions", "Health & Medical", "Education", "Investment", "Refund", "Other"]
- "merchant": (string) Clean name of merchant or recipient/sender (e.g., "Swiggy", "Zomato", "Uber", "Blinkit", "Amazon", "Airtel", "HDFC Loan", "Ramesh Kumar").
- "paymentMode": (string) "UPI", "Debit Card", "Credit Card", "NetBanking", "ATM", or "Unknown".

Return strictly raw valid JSON with NO markdown backticks or explanation:
{"isTransaction":true,"amount":450.0,"type":"debit","category":"Food Delivery","merchant":"Swiggy","paymentMode":"UPI"}
''';

    // Prioritize working model if already discovered
    final modelsToTry = _workingModel != null
        ? [_workingModel!, ...candidateModels.where((m) => m != _workingModel)]
        : candidateModels;

    for (final modelName in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
        );

        final response = await model.generateContent([Content.text(prompt)]);
        final responseText = response.text;

        if (responseText == null || responseText.isEmpty) {
          continue;
        }

        // Clean response if markdown code fences are present
        String jsonString = responseText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        if (jsonString.toLowerCase() == 'null' || jsonString.isEmpty) {
          return null;
        }

        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        if (decoded['isTransaction'] == false) {
          return null;
        }

        // Remember the model that worked
        _workingModel = modelName;
        return decoded;
      } catch (e) {
        print('Gemini ($modelName) parsing failed: $e');
        // Continue to next candidate model
      }
    }

    return null;
  }

  // Quick test to verify connectivity with the configured API key
  Future<bool> testConnection({String? apiKey}) async {
    final keyToTest = apiKey?.trim() ?? activeApiKey;
    if (keyToTest.isEmpty) return false;

    for (final modelName in candidateModels) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: keyToTest,
        );
        final response = await model.generateContent([
          Content.text('Respond with {"status":"ok"} in JSON format')
        ]);
        if (response.text != null && response.text!.isNotEmpty) {
          _workingModel = modelName;
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }
}
