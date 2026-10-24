import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/models/transaction_model.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/currency_formatter.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._init();

  // Initialize notifications
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDescription,
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // Show notification for a new transaction
  Future<void> showTransactionNotification(TransactionModel transaction) async {
    final title = transaction.isCredit
        ? '💰 Income Received'
        : '💸 Expense Recorded';

    final body = transaction.isCredit
        ? '${CurrencyFormatter.format(transaction.amount)} from ${transaction.description}'
        : '${CurrencyFormatter.format(transaction.amount)} on ${transaction.category} at ${transaction.description}';

    await _showNotification(
      id: transaction.hashCode,
      title: title,
      body: body,
      payload: transaction.id,
    );
  }

  // Show a custom notification
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Show budget alert notification
  Future<void> showBudgetAlert({
    required double spent,
    required double budget,
  }) async {
    final percentage = (spent / budget) * 100;
    
    String title;
    String body;

    if (percentage >= 100) {
      title = '⚠️ Budget Exceeded!';
      body = 'You\'ve spent ${CurrencyFormatter.format(spent)} out of ${CurrencyFormatter.format(budget)} budget';
    } else if (percentage >= 80) {
      title = '⚠️ Budget Alert';
      body = 'You\'ve used ${percentage.toStringAsFixed(0)}% of your monthly budget';
    } else {
      return; // Don't show notification if under 80%
    }

    await _showNotification(
      id: 999, // Fixed ID for budget alerts
      title: title,
      body: body,
    );
  }

  // Show insight notification
  Future<void> showInsightNotification(String insight) async {
    await _showNotification(
      id: 1000, // Fixed ID for insights
      title: '💡 Financial Insight',
      body: insight,
    );
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Navigate to specific transaction or screen
    // This will be implemented when we add navigation
    final payload = response.payload;
    if (payload != null) {
      // Navigate to transaction details
      print('Notification tapped with payload: $payload');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }

    return true; // Assume granted for older Android versions
  }
}
