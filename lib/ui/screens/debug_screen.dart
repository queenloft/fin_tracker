import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/sms_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final SmsService _smsService = SmsService();
  bool _isLoading = false;
  String? _error;
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Debug Info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _scanSms,
            tooltip: 'Scan SMS',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (!_hasScanned) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bug_report,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tap the refresh button to scan SMS',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _scanSms,
              icon: const Icon(Icons.search),
              label: const Text('Scan SMS Now'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          
          // Statistics Card
          _buildStatisticsCard(),
          const SizedBox(height: 16),
          
          // Filtered Samples
          if (_smsService.filteredOutSamples.isNotEmpty) ...[
            _buildFilteredSamplesCard(),
            const SizedBox(height: 16),
          ],
          
          // Debug Logs
          if (_smsService.debugLogs.isNotEmpty) ...[
            _buildDebugLogsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final total = _smsService.totalSmsRead;
    final bankSenderFiltered = _smsService.bankSenderFiltered;
    final transactionFiltered = _smsService.transactionFiltered;
    final otpFiltered = _smsService.otpFiltered;
    final finalBankSms = _smsService.finalBankSms;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'SMS Filtering Statistics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow('Total SMS Read', total, Colors.blue),
            const SizedBox(height: 8),
            _buildStatRow('Non-Bank Sender', bankSenderFiltered, Colors.orange),
            const SizedBox(height: 8),
            _buildStatRow('No Transaction Keywords', transactionFiltered, Colors.orange),
            const SizedBox(height: 8),
            _buildStatRow('OTP Filtered', otpFiltered, Colors.orange),
            const Divider(height: 24),
            _buildStatRow('✓ Valid Bank SMS', finalBankSms, Colors.green, isBold: true),
            const SizedBox(height: 16),
            
            // Success Rate
            if (total > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: finalBankSms > 0 ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detection Rate:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: finalBankSms > 0 ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                    Text(
                      '${((finalBankSms / total) * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: finalBankSms > 0 ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredSamplesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Filtered Out Samples',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'These SMS were filtered out (showing up to 10)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            ..._smsService.filteredOutSamples.map((sample) => _buildSampleItem(sample)),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleItem(Map<String, String> sample) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  sample['sender'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            sample['body'] ?? '',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              sample['reason'] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLogsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.terminal, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Debug Logs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyLogsToClipboard,
                  tooltip: 'Copy logs',
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _smsService.debugLogs.map((log) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.greenAccent,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanSms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check permissions
      final hasPermission = await _smsService.hasPermissions();
      if (!hasPermission) {
        final granted = await _smsService.requestPermissions();
        if (!granted) {
          setState(() {
            _error = 'SMS permission is required';
            _isLoading = false;
          });
          return;
        }
      }

      // Read SMS (this will populate debug stats)
      await _smsService.readExistingSMS();

      setState(() {
        _hasScanned = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyLogsToClipboard() {
    final logs = _smsService.debugLogs.join('\n');
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }
}
