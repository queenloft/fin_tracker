import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants/app_constants.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: AppConstants.geminiApiKey,
    );
  }

  Future<Map<String, dynamic>?> parseSms(String smsBody) async {
    try {
      final prompt = '''
      Analyze the following SMS and extract transaction details in JSON format.
      
      SMS: "$smsBody"
      
      Return ONLY a JSON object with the following fields:
      - amount: (double) The transaction amount.
      - type: (string) "credit" or "debit".
      - category: (string) The category of the transaction (e.g., Food, Transport, Shopping, Salary, etc.). Infer this from the merchant or description.
      - merchant: (string) The name of the merchant or sender/receiver.
      - paymentMode: (string) The mode of payment (e.g., UPI, Card, NetBanking, ATM).
      
      If the SMS is not a transaction or details cannot be extracted, return null.
      Do not include any markdown formatting or explanations, just the raw JSON.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.isEmpty) {
        return null;
      }

      // Clean up the response if it contains markdown code blocks
      String jsonString = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      
      // Handle "null" string response
      if (jsonString.toLowerCase() == 'null') {
        return null;
      }

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error parsing SMS with Gemini: $e');
      return null;
    }
  }
}
