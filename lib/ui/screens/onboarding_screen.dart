import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/analytics_provider.dart';
import '../../services/sms_service.dart';
import '../../services/notification_service.dart';
import 'dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final SmsService _smsService = SmsService();
  final NotificationService _notificationService = NotificationService.instance;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Icon/Logo
              Icon(
                Icons.account_balance_wallet,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // App Title
              Text(
                'FinTracker',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Your Personal Finance Assistant',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Features List
              _buildFeatureItem(
                icon: Icons.sms,
                title: 'Automatic Tracking',
                description: 'Reads bank SMS to track income and expenses',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.category,
                title: 'Smart Categorization',
                description: 'Automatically categorizes your transactions',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.insights,
                title: 'Financial Insights',
                description: 'Get personalized tips to manage your money',
              ),
              const SizedBox(height: 16),
              _buildFeatureItem(
                icon: Icons.security,
                title: 'Privacy First',
                description: 'All data stays on your device',
              ),
              const SizedBox(height: 48),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Grant Permission Button
              ElevatedButton(
                onPressed: _isLoading ? null : _requestPermissions,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Grant SMS Permission'),
              ),
              const SizedBox(height: 16),

              // Privacy Note
              Text(
                'We need SMS permission to read bank messages and track your transactions. Your data is never sent to external servers.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Request SMS permission
      final smsGranted = await _smsService.requestPermissions();
      
      if (!smsGranted) {
        setState(() {
          _error = 'SMS permission is required to use this app';
          _isLoading = false;
        });
        return;
      }

      // Request notification permission
      await _notificationService.requestPermissions();

      // Mark first launch as complete
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.completeFirstLaunch();

      // Sync ALL transactions from SMS (no limit on first install)
      if (mounted) {
        
        setState(() {
          _error = 'Reading all SMS messages... This may take a moment.';
        });
      }
      
      final transactionProvider = context.read<TransactionProvider>();
      await transactionProvider.syncFromSMS(); // No limit - reads all SMS
      
      // Update analytics after sync
      if (mounted) {
        final analyticsProvider = context.read<AnalyticsProvider>();
        analyticsProvider.updateAnalytics(transactionProvider.filteredTransactions);
        
        // Update monthly trend
        analyticsProvider.updateMonthlyTrend(
          transactionProvider.allTransactions,
          6,
        );
      }

      // Navigate to dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DashboardScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
}
