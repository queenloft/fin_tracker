import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/parser_service.dart';
import '../../services/sms_service.dart';
import '../../services/categorization_service.dart';
import '../../data/models/transaction_model.dart';

class ImportSmsScreen extends StatefulWidget {
  const ImportSmsScreen({super.key});

  @override
  State<ImportSmsScreen> createState() => _ImportSmsScreenState();
}

class _ImportSmsScreenState extends State<ImportSmsScreen> {
  final _textController = TextEditingController();
  final ParserService _parserService = ParserService();
  final SmsService _smsService = SmsService();
  
  List<TransactionModel> _parsedTransactions = [];
  bool _isProcessing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import SMS'),
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paste bank transaction SMS messages below. Each SMS should be on a new line.',
                    style: TextStyle(color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),

          // SMS Input
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Paste SMS messages here...\n\nExample:\nYour A/c XX1234 debited with Rs.500.00 on 22-Nov-25',
                  border: OutlineInputBorder(),
                ),
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),

          // Process Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processSms,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : const Text('Process SMS'),
              ),
            ),
          ),

          // Error Message
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red[50],
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),
                ],
              ),
            ),

          // Parsed Transactions Preview
          if (_parsedTransactions.isNotEmpty)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Found ${_parsedTransactions.length} transactions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        ElevatedButton(
                          onPressed: _importTransactions,
                          child: const Text('Import All'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _parsedTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _parsedTransactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Icon(
                              transaction.isCredit
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: transaction.isCredit
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(transaction.description),
                            subtitle: Text(
                              '${transaction.category} • ${transaction.dateTime.day}/${transaction.dateTime.month}/${transaction.dateTime.year}',
                            ),
                            trailing: Text(
                              '₹${transaction.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: transaction.isCredit
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _processSms() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _parsedTransactions = [];
    });

    try {
      final text = _textController.text.trim();
      if (text.isEmpty) {
        setState(() {
          _error = 'Please paste some SMS messages';
          _isProcessing = false;
        });
        return;
      }

      // Split by newlines to get individual SMS
      final smsLines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
      
      final transactions = <TransactionModel>[];
      
      for (final sms in smsLines) {
        try {
          TransactionModel? parsed;
          
          // 1. Try AI Assistant analysis first
          try {
            final aiResult = await _smsService.parseSmsWithAi(sms);
            if (aiResult != null && aiResult['isTransaction'] != false) {
              parsed = _parserService.createTransactionFromAiResult(
                aiResult: aiResult,
                smsBody: sms,
                sender: 'Manual',
                receivedDate: DateTime.now(),
              );
            }
          } catch (_) {}

          // 2. Fallback to enhanced high-accuracy regex parser
          parsed ??= _parserService.parseSMS(
            smsBody: sms,
            sender: 'Manual',
            receivedDate: DateTime.now(),
          );
          
          if (parsed != null) {
            transactions.add(parsed);
          }
        } catch (e) {
          // Skip invalid SMS
          print('Failed to parse SMS: $sms - Error: $e');
        }
      }

      if (transactions.isEmpty) {
        setState(() {
          _error = 'No valid transaction SMS found. Make sure the messages contain amount and transaction keywords.';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _parsedTransactions = transactions;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error processing SMS: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _importTransactions() async {
    try {
      final transactionProvider = context.read<TransactionProvider>();
      
      for (final transaction in _parsedTransactions) {
        await transactionProvider.addTransaction(transaction);
      }
      
      // Refresh transactions and analytics
      await transactionProvider.loadTransactions();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${_parsedTransactions.length} transactions'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
