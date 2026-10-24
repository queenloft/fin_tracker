import 'package:flutter/material.dart';
import '../../services/notification_listener_service.dart' as app_service;

class NotificationListenerScreen extends StatefulWidget {
  const NotificationListenerScreen({super.key});

  @override
  State<NotificationListenerScreen> createState() => _NotificationListenerScreenState();
}

class _NotificationListenerScreenState extends State<NotificationListenerScreen> {
  final app_service.NotificationListenerService _service = app_service.NotificationListenerService();
  bool _isListening = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await app_service.SystemNotificationListenerService.isPermissionGranted();
    setState(() {
      _hasPermission = hasPermission;
      _isListening = _service.isListening;
    });
  }

  Future<void> _requestPermission() async {
    await app_service.SystemNotificationListenerService.requestPermission();
    await _checkPermission();
  }

  Future<void> _toggleListener() async {
    if (_isListening) {
      _service.stopListening();
      setState(() {
        _isListening = false;
      });
    } else {
      final started = await _service.startListening();
      setState(() {
        _isListening = started;
      });
      
      if (!started) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start notification listener. Please grant permission.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Listener'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FinTracker will listen to payment notifications from UPI apps and banks to automatically track your transactions.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Permission Status
          ListTile(
            leading: Icon(
              _hasPermission ? Icons.check_circle : Icons.cancel,
              color: _hasPermission ? Colors.green : Colors.red,
            ),
            title: const Text('Notification Access'),
            subtitle: Text(
              _hasPermission ? 'Permission granted' : 'Permission required',
            ),
            trailing: _hasPermission
                ? null
                : ElevatedButton(
                    onPressed: _requestPermission,
                    child: const Text('Grant'),
                  ),
          ),
          const Divider(),

          // Listener Status
          ListTile(
            leading: Icon(
              _isListening ? Icons.notifications_active : Icons.notifications_off,
              color: _isListening ? Colors.green : Colors.grey,
            ),
            title: const Text('Listener Status'),
            subtitle: Text(
              _isListening ? 'Active - Capturing notifications' : 'Inactive',
            ),
            trailing: Switch(
              value: _isListening,
              onChanged: _hasPermission ? (value) => _toggleListener() : null,
            ),
          ),
          const Divider(),

          const SizedBox(height: 24),

          // Supported Apps
          Text(
            'Supported Apps',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          _buildAppCategory(
            'UPI Apps',
            ['Google Pay', 'PhonePe', 'Paytm', 'BHIM'],
            Icons.payment,
          ),
          const SizedBox(height: 16),

          _buildAppCategory(
            'Banks',
            ['HDFC', 'ICICI', 'SBI', 'Axis', 'Kotak', 'PNB', 'BOB'],
            Icons.account_balance,
          ),
          const SizedBox(height: 16),

          _buildAppCategory(
            'Wallets',
            ['Amazon Pay', 'Mobikwik', 'Freecharge'],
            Icons.account_balance_wallet,
          ),

          const SizedBox(height: 32),

          // Privacy Note
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Privacy & Security',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Only payment app notifications are processed\n'
                    '• All data stays on your device\n'
                    '• No data is sent to external servers\n'
                    '• You can disable this anytime',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppCategory(String title, List<String> apps, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: apps.map((app) {
                return Chip(
                  label: Text(app, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.grey[200],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
