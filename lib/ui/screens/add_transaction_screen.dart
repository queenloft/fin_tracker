import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../services/categorization_service.dart';
import '../../services/parser_service.dart';
import '../../services/sms_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _smsTextController = TextEditingController();
  final CategorizationService _categorizationService = CategorizationService();
  final ParserService _parserService = ParserService();
  final SmsService _smsService = SmsService();
  
  bool _isCredit = false;
  String _selectedCategory = 'Other';
  DateTime _selectedDate = DateTime.now();
  bool _showSmsParser = false;
  bool _isParsing = false;
  TransactionModel? _parsedTransaction;
  String? _parseError;
  
  final List<String> _categories = [
    'Food & Dining',
    'Shopping',
    'Transportation',
    'Bills & Utilities',
    'Entertainment',
    'Healthcare',
    'Groceries',
    'Education',
    'Travel',
    'Salary',
    'Investment',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        actions: [
          IconButton(
            icon: Icon(_showSmsParser ? Icons.edit : Icons.message),
            tooltip: _showSmsParser ? 'Manual Entry' : 'Parse SMS',
            onPressed: () {
              setState(() {
                _showSmsParser = !_showSmsParser;
                _parsedTransaction = null;
                _parseError = null;
                _smsTextController.clear();
              });
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // SMS Parser Section
            if (_showSmsParser) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.message, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Paste Bank SMS',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _smsTextController,
                        decoration: InputDecoration(
                          labelText: 'SMS Text',
                          hintText: 'Paste your bank transaction SMS here...',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste),
                            onPressed: _pasteFromClipboard,
                          ),
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isParsing ? null : _parseSms,
                          icon: _isParsing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.analytics),
                          label: Text(_isParsing ? 'Analyzing...' : 'Extract Transaction'),
                        ),
                      ),
                      if (_parseError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _parseError!,
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Parsed Transaction Visualization
              if (_parsedTransaction != null) ...[
                Card(
                  elevation: 4,
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Extracted Transaction',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.green[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildExtractedDataRow(
                          'Type',
                          _parsedTransaction!.isCredit ? 'Income' : 'Expense',
                          _parsedTransaction!.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                          _parsedTransaction!.isCredit ? Colors.green : Colors.red,
                        ),
                        _buildExtractedDataRow(
                          'Amount',
                          '₹${_parsedTransaction!.amount.toStringAsFixed(2)}',
                          Icons.currency_rupee,
                          Colors.blue,
                        ),
                        _buildExtractedDataRow(
                          'Category',
                          _parsedTransaction!.category,
                          Icons.category,
                          Colors.purple,
                        ),
                        _buildExtractedDataRow(
                          'Description',
                          _parsedTransaction!.description,
                          Icons.description,
                          Colors.orange,
                        ),
                        _buildExtractedDataRow(
                          'Bank',
                          _parsedTransaction!.bankName,
                          Icons.account_balance,
                          Colors.indigo,
                        ),
                        _buildExtractedDataRow(
                          'Date',
                          '${_parsedTransaction!.dateTime.day}/${_parsedTransaction!.dateTime.month}/${_parsedTransaction!.dateTime.year}',
                          Icons.calendar_today,
                          Colors.teal,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saveParsedTransaction,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Transaction'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            
            // Manual Entry Section (only show if not in SMS parser mode or no parsed transaction)
            if (!_showSmsParser || _parsedTransaction == null) ...[
            // Type Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Expense'),
                        selected: !_isCredit,
                        onSelected: (selected) {
                          setState(() {
                            _isCredit = false;
                          });
                        },
                        selectedColor: Colors.red[100],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Income'),
                        selected: _isCredit,
                        onSelected: (selected) {
                          setState(() {
                            _isCredit = true;
                          });
                        },
                        selectedColor: Colors.green[100],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'e.g., Grocery shopping, Salary, etc.',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Transaction'),
            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedDataRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _smsTextController.text = clipboardData.text!;
      });
    }
  }

  Future<void> _parseSms() async {
    if (_smsTextController.text.trim().isEmpty) {
      setState(() {
        _parseError = 'Please paste SMS text first';
      });
      return;
    }

    setState(() {
      _isParsing = true;
      _parseError = null;
      _parsedTransaction = null;
    });

    try {
      final smsText = _smsTextController.text.trim();
      TransactionModel? transaction;

      // Try AI parsing first
      try {
        final aiResult = await _smsService.parseSmsWithAi(smsText);
        if (aiResult != null) {
          transaction = _parserService.createTransactionFromAiResult(
            aiResult: aiResult,
            smsBody: smsText,
            sender: 'Pasted SMS',
            receivedDate: DateTime.now(),
          );
        }
      } catch (e) {
        print('AI parsing failed, trying regex: $e');
      }

      // Fallback to regex parsing
      if (transaction == null) {
        transaction = _parserService.parseSMS(
          smsBody: smsText,
          sender: 'Pasted SMS',
          receivedDate: DateTime.now(),
        );
      }

      if (transaction != null) {
        setState(() {
          _parsedTransaction = transaction;
          _isParsing = false;
        });
      } else {
        setState(() {
          _parseError = 'Could not extract transaction details from SMS. Please check the SMS format.';
          _isParsing = false;
        });
      }
    } catch (e) {
      setState(() {
        _parseError = 'Error parsing SMS: ${e.toString()}';
        _isParsing = false;
      });
    }
  }

  Future<void> _saveParsedTransaction() async {
    if (_parsedTransaction == null) return;

    try {
      final provider = context.read<TransactionProvider>();
      await provider.addTransaction(_parsedTransaction!);

      if (mounted) {
        // Navigate back first
        Navigator.pop(context);
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction added successfully! Dashboard will update automatically.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.parse(_amountController.text);
    final description = _descriptionController.text;

    final transaction = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: _selectedDate,
      amount: amount,
      isCredit: _isCredit,
      category: _selectedCategory,
      description: description,
      bankName: 'Manual Entry',
      rawSms: 'Manually added transaction',
    );

    try {
      final provider = context.read<TransactionProvider>();
      await provider.addTransaction(transaction);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction added successfully! Dashboard will update automatically.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
    _amountController.dispose();
    _descriptionController.dispose();
    _smsTextController.dispose();
    super.dispose();
  }
}
