import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/database/database_helper.dart';
import '../../services/gemini_service.dart';
import 'debug_screen.dart';
import 'import_sms_screen.dart';
import 'import_file_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;

  Future<void> _showSyncOptions() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync SMS with AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Sync Last 30 Days'),
              subtitle: const Text('Analyzes recent SMS with AI'),
              onTap: () {
                Navigator.pop(context);
                _syncSMS(limit: 500);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Sync All Time'),
              subtitle: const Text('Analyzes all bank SMS messages'),
              onTap: () {
                Navigator.pop(context);
                _syncSMS();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncSMS({int? limit}) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final transactionProvider = context.read<TransactionProvider>();
      await transactionProvider.syncFromSMS(limit: limit);
      
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS sync complete! Found ${transactionProvider.allTransactions.length} total transactions'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // AI Assistant Section
              _buildSectionHeader('AI Assistant'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.auto_awesome, color: Colors.blue[700]),
                      ),
                      title: const Text('Gemini AI SMS Analyzer'),
                      subtitle: Text(
                        provider.hasCustomGeminiKey
                            ? 'Custom API Key Active'
                            : 'Camspot Credentials Active',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Icon(Icons.edit_outlined, color: Colors.grey[600]),
                      onTap: () => _showAiConfigDialog(context, provider),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Preferences Section
              _buildSectionHeader('Preferences'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Notifications'),
                      subtitle: const Text('Get notified for new transactions'),
                      value: provider.notificationsEnabled,
                      onChanged: (value) {
                        provider.setNotificationsEnabled(value);
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.notifications, color: Colors.blue[700]),
                      ),
                    ),
                    const Divider(height: 1, indent: 72),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.account_balance_wallet, color: Colors.green[700]),
                      ),
                      title: const Text('Monthly Budget'),
                      subtitle: Text(
                        provider.monthlyBudget != null
                            ? '₹${provider.monthlyBudget!.toStringAsFixed(0)}'
                            : 'Not set',
                        style: TextStyle(
                          color: provider.monthlyBudget != null ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(Icons.edit_outlined, color: Colors.grey[600]),
                      onTap: () => _showBudgetDialog(context, provider),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Data Management Section
              _buildSectionHeader('Data Management'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.sync, color: Colors.purple[700]),
                      ),
                      title: const Text('Sync SMS'),
                      subtitle: const Text('Re-sync with AI analysis'),
                      trailing: _isSyncing 
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: _isSyncing ? null : _showSyncOptions,
                    ),
                    const Divider(height: 1, indent: 72),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.paste, color: Colors.teal[700]),
                      ),
                      title: const Text('Paste & Analyze SMS'),
                      subtitle: const Text('Test AI analysis on pasted SMS'),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ImportSmsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 72),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.upload_file, color: Colors.orange[700]),
                      ),
                      title: const Text('Import File'),
                      subtitle: const Text('Import CSV/XML SMS backup'),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ImportFileScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Developer Tools Section
              _buildSectionHeader('Developer Tools'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.bug_report, color: Colors.amber[700]),
                  ),
                  title: const Text('Debug Info'),
                  subtitle: const Text('View SMS filtering diagnostics'),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DebugScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Danger Zone Section
              _buildSectionHeader('Danger Zone'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                color: Colors.red[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_forever, color: Colors.red[700]),
                  ),
                  title: Text(
                    'Clear All Data',
                    style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Delete all transactions permanently'),
                  trailing: Icon(Icons.chevron_right, color: Colors.red[300]),
                  onTap: () => _showClearDataDialog(context),
                ),
              ),

              const SizedBox(height: 24),

              // About Section
              _buildSectionHeader('About'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.info_outline, color: Colors.indigo[700]),
                      ),
                      title: const Text('Version'),
                      subtitle: const Text('1.0.0'),
                    ),
                    const Divider(height: 1, indent: 72),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.code, color: Colors.teal[700]),
                      ),
                      title: const Text('FinTracker'),
                      subtitle: const Text('AI-powered SMS expense tracker'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showAiConfigDialog(BuildContext context, SettingsProvider provider) {
    final controller = TextEditingController(
      text: provider.hasCustomGeminiKey ? provider.geminiApiKey : '',
    );
    bool testing = false;
    String? testResult;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue),
              SizedBox(width: 8),
              Text('AI Assistant Config'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FinTracker uses Gemini AI to extract exact amounts, categories, and merchants from bank SMS.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: provider.hasCustomGeminiKey
                      ? 'Custom key configured'
                      : 'Default Camspot key active',
                  border: const OutlineInputBorder(),
                  suffixIcon: provider.hasCustomGeminiKey
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.clear();
                            setDialogState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              if (testResult != null)
                Text(
                  testResult!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: testResult!.startsWith('Success') ? Colors.green : Colors.red,
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: testing
                    ? null
                    : () async {
                        setDialogState(() {
                          testing = true;
                          testResult = 'Testing connection...';
                        });
                        final keyToTest = controller.text.trim().isNotEmpty
                            ? controller.text.trim()
                            : provider.geminiApiKey;
                        final ok = await GeminiService.instance.testConnection(apiKey: keyToTest);
                        setDialogState(() {
                          testing = false;
                          testResult = ok
                              ? 'Success: Gemini AI connection verified!'
                              : 'Notice: Key tested. Fallback models and enhanced parser active.';
                        });
                      },
                icon: testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Test Connection'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            if (provider.hasCustomGeminiKey)
              TextButton(
                onPressed: () {
                  provider.setGeminiApiKey(null);
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset to Camspot default credentials')),
                  );
                },
                child: const Text('Reset Default'),
              ),
            TextButton(
              onPressed: () {
                final key = controller.text.trim();
                provider.setGeminiApiKey(key.isNotEmpty ? key : null);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI Assistant configuration saved')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, SettingsProvider provider) {
    final controller = TextEditingController(
      text: provider.monthlyBudget?.toStringAsFixed(0) ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Budget Amount',
            prefixText: '₹',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final budget = double.tryParse(controller.text);
              provider.setMonthlyBudget(budget);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete all transactions. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final transactionProvider = context.read<TransactionProvider>();
              await DatabaseHelper.instance.clearAllData();
              await transactionProvider.loadTransactions();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
