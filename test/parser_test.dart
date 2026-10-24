import 'package:flutter_test/flutter_test.dart';
import 'package:fin_tracker/services/parser_service.dart';
import 'package:fin_tracker/core/constants/app_constants.dart';

void main() {
  late ParserService parser;

  setUp(() {
    parser = ParserService();
  });

  group('ParserService SMS Analysis Tests', () {
    test('Correctly parses Swiggy debit transaction and avoids available balance', () {
      const sms = 'Dear SBI User, your A/c ending 1234 has been debited by Rs. 450.00 on 24-Oct-26 at SWIGGY BANGALORE via UPI ref 12345. Avl Bal Rs 5,400';
      final txn = parser.parseSMS(
        smsBody: sms,
        sender: 'SBI-INB',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNotNull);
      expect(txn!.amount, 450.0);
      expect(txn.isCredit, false);
      expect(txn.category, AppConstants.categoryFood);
      expect(txn.description.toLowerCase(), contains('swiggy'));
    });

    test('Correctly parses Salary credit transaction', () {
      const sms = 'Your A/c ending 5678 is credited with Rs 65,000.00 on 01-Oct-26 by Salary Oct 2026. Avl Bal Rs 80,000';
      final txn = parser.parseSMS(
        smsBody: sms,
        sender: 'HDFC-SAL',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNotNull);
      expect(txn!.amount, 65000.0);
      expect(txn.isCredit, true);
      expect(txn.category, AppConstants.categorySalary);
    });

    test('Correctly parses Zomato UPI VPA transaction', () {
      const sms = 'Rs 280.00 debited from A/c XX9999 to VPA zomato@icici via UPI. Avl Bal: INR 12,000';
      final txn = parser.parseSMS(
        smsBody: sms,
        sender: 'AXIS-UPI',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNotNull);
      expect(txn!.amount, 280.0);
      expect(txn.isCredit, false);
      expect(txn.category, AppConstants.categoryFood);
      expect(txn.description.toLowerCase(), contains('zomato'));
    });

    test('Correctly parses Uber ride expense', () {
      const sms = 'Paid Rs. 350 to Uber on 22-Oct-26 via Paytm UPI.';
      final txn = parser.parseSMS(
        smsBody: sms,
        sender: 'Paytm',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNotNull);
      expect(txn!.amount, 350.0);
      expect(txn.isCredit, false);
      expect(txn.category, AppConstants.categoryTransport);
    });

    test('Correctly parses Blinkit grocery expense', () {
      const sms = 'Your card ending 4321 was charged Rs 820.50 at BLINKIT GURGAON. Bal: Rs 40,000';
      final txn = parser.parseSMS(
        smsBody: sms,
        sender: 'ICICI-CARD',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNotNull);
      expect(txn!.amount, 820.50);
      expect(txn.isCredit, false);
      expect(txn.category, AppConstants.categoryGroceries);
    });

    test('Correctly parses EMI loan payment', () {
      const sms = 'EMI of Rs 4,500.00 debited from your A/c for Loan 987654';
      final txn = parser.parseSMS(
        smsBody: sms,
        sender: 'HDFC-LOAN',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNotNull);
      expect(txn!.amount, 4500.0);
      expect(txn.isCredit, false);
      expect(txn.category, AppConstants.categoryEMI);
    });

    test('Correctly rejects OTP message', () {
      const sms = '123456 is your OTP for transaction of Rs 500 at Amazon. Do not share with anyone.';
      final txn = parser.parseSMS(
        smsBody: sms,
        sender: 'AMAZON',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNull);
    });

    test('Correctly rejects promotional offer', () {
      const sms = 'Congratulations! You have pre-approved loan of Rs 5,00,000. Click here to apply.';
      final txn = parser.parseSMS(
        smsBody: sms,
        sender: 'BAJAJ',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNull);
    });

    test('createTransactionFromAiResult properly maps AI output', () {
      final aiResult = {
        'isTransaction': true,
        'amount': 799.0,
        'type': 'debit',
        'category': 'Subscriptions',
        'merchant': 'Netflix',
        'paymentMode': 'Credit Card',
      };

      final txn = parser.createTransactionFromAiResult(
        aiResult: aiResult,
        smsBody: 'INR 799.00 debited on card ending 1234 for NETFLIX',
        sender: 'HDFC-BNK',
        receivedDate: DateTime.now(),
      );

      expect(txn, isNotNull);
      expect(txn!.amount, 799.0);
      expect(txn.isCredit, false);
      expect(txn.category, 'Subscriptions');
      expect(txn.description, 'Netflix');
    });
  });
}
