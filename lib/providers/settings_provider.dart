import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class SettingsProvider with ChangeNotifier {
  bool _notificationsEnabled = true;
  double? _monthlyBudget;
  bool _isFirstLaunch = true;

  bool get notificationsEnabled => _notificationsEnabled;
  double? get monthlyBudget => _monthlyBudget;
  bool get isFirstLaunch => _isFirstLaunch;

  // Initialize settings from shared preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    _notificationsEnabled = prefs.getBool(
      AppConstants.prefKeyNotificationsEnabled,
    ) ?? true;
    
    _monthlyBudget = prefs.getDouble(AppConstants.prefKeyMonthlyBudget);
    
    _isFirstLaunch = prefs.getBool(AppConstants.prefKeyFirstLaunch) ?? true;
    
    notifyListeners();
  }

  // Set notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefKeyNotificationsEnabled, enabled);
  }

  // Set monthly budget
  Future<void> setMonthlyBudget(double? budget) async {
    _monthlyBudget = budget;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (budget != null) {
      await prefs.setDouble(AppConstants.prefKeyMonthlyBudget, budget);
    } else {
      await prefs.remove(AppConstants.prefKeyMonthlyBudget);
    }
  }

  // Mark first launch as complete
  Future<void> completeFirstLaunch() async {
    _isFirstLaunch = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefKeyFirstLaunch, false);
  }

  // Clear all settings
  Future<void> clearAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    _notificationsEnabled = true;
    _monthlyBudget = null;
    _isFirstLaunch = true;
    
    notifyListeners();
  }
}
