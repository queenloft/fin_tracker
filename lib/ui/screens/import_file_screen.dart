import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';
import '../../providers/transaction_provider.dart';
import '../../services/parser_service.dart';
import '../../data/models/transaction_model.dart';

class ImportFileScreen extends StatefulWidget {
  const ImportFileScreen({super.key});

  @override
  State<ImportFileScreen> createState() => _ImportFileScreenState();
}

class _ImportFileScreenState extends State<ImportFileScreen> {
  final ParserService _parserService = ParserService();
  
  List<TransactionModel> _parsedTransactions = [];
  bool _isProcessing = false;
  String? _error;
  String? _fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import File'),
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Import SMS from backup files',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported formats:\n'
                  '• CSV - Comma-separated values\n'
                  '• XML - SMS Backup & Restore format',
                  style: TextStyle(color: Colors.blue[800], fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // File Picker Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Select File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          if (_fileName != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Selected: $_fileName',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),

          // Error Message
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
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

          // Processing Indicator
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing file...'),
                ],
              ),
            ),

          // Parsed Transactions Preview
          if (_parsedTransactions.isNotEmpty)
            Expanded(
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
                          onPressed: _isProcessing ? null : _importTransactions,
                          child: _isProcessing 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Import All'),
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xml'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        
        setState(() {
          _fileName = fileName;
          _isProcessing = true;
          _error = null;
          _parsedTransactions = [];
        });

        if (fileName.toLowerCase().endsWith('.csv')) {
          await _processCsvFile(file);
        } else if (fileName.toLowerCase().endsWith('.xml')) {
          await _processXmlFile(file);
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error picking file: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processCsvFile(File file) async {
    try {
      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);
      
      if (rows.isEmpty) {
        setState(() {
          _error = 'CSV file is empty';
          _isProcessing = false;
        });
        return;
      }

      final transactions = <TransactionModel>[];
      
      // Try to detect CSV format
      // Common formats:
      // 1. Address, Body, Date
      // 2. Sender, Message, Timestamp
      
      for (var i = 1; i < rows.length; i++) { // Skip header
        final row = rows[i];
        if (row.length < 2) continue;
        
        try {
          String sender = row[0].toString();
          String body = row.length > 1 ? row[1].toString() : '';
          DateTime date = DateTime.now();
          
          // Try to parse date from third column if exists
          if (row.length > 2) {
            try {
              final dateStr = row[2].toString();
              // Try parsing as milliseconds first
              if (int.tryParse(dateStr) != null) {
                date = DateTime.fromMillisecondsSinceEpoch(int.parse(dateStr));
              } else {
                date = DateTime.parse(dateStr);
              }
            } catch (e) {
              // Use current date if parsing fails
            }
          }
          
          final parsed = _parserService.parseSMS(
            smsBody: body,
            sender: sender,
            receivedDate: date,
          );
          
          if (parsed != null) {
            transactions.add(parsed);
          }
        } catch (e) {
          // Skip invalid rows
          print('Failed to parse row $i: $e');
        }
      }

      if (transactions.isEmpty) {
        setState(() {
          _error = 'No valid transaction SMS found in CSV file';
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
        _error = 'Error processing CSV: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _processXmlFile(File file) async {
    try {
      final content = await file.readAsString();
      final document = XmlDocument.parse(content);
      
      final transactions = <TransactionModel>[];
      
      // Parse SMS Backup & Restore XML format
      final smsElements = document.findAllElements('sms');
      
      for (final sms in smsElements) {
        try {
          final address = sms.getAttribute('address') ?? '';
          final body = sms.getAttribute('body') ?? '';
          final dateStr = sms.getAttribute('date') ?? '0';
          
          final date = DateTime.fromMillisecondsSinceEpoch(
            int.tryParse(dateStr) ?? 0,
          );
          
          final parsed = _parserService.parseSMS(
            smsBody: body,
            sender: address,
            receivedDate: date,
          );
          
          if (parsed != null) {
            transactions.add(parsed);
          }
        } catch (e) {
          // Skip invalid SMS
          print('Failed to parse SMS element: $e');
        }
      }

      if (transactions.isEmpty) {
        setState(() {
          _error = 'No valid transaction SMS found in XML file';
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
        _error = 'Error processing XML: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _importTransactions() async {
    if (_parsedTransactions.isEmpty) return;
    
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final transactionProvider = context.read<TransactionProvider>();
      
      print('=== Starting File Import ===');
      print('Importing ${_parsedTransactions.length} transactions...');
      
      int imported = 0;
      int failed = 0;
      
      // Import in batches of 50 for better performance
      const batchSize = 50;
      for (var i = 0; i < _parsedTransactions.length; i += batchSize) {
        final end = (i + batchSize < _parsedTransactions.length) 
            ? i + batchSize 
            : _parsedTransactions.length;
        final batch = _parsedTransactions.sublist(i, end);
        
        try {
          for (final transaction in batch) {
            await transactionProvider.addTransaction(transaction);
            imported++;
          }
          print('Imported batch: $i-$end (Total: $imported/${_parsedTransactions.length})');
        } catch (e) {
          print('Error importing batch $i-$end: $e');
          failed += batch.length;
        }
      }
      
      print('Import complete: Imported=$imported, Failed=$failed');
      
      // Force reload of all transactions
      await transactionProvider.loadTransactions();
      print('Transactions reloaded from database');
      print('=== File Import Complete ===');

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $imported transactions${failed > 0 ? ", $failed failed" : ""}'),
            duration: const Duration(seconds: 4),
            backgroundColor: failed > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      print('ERROR in _importTransactions: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Import failed: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
