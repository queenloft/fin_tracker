import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../services/gemini_service.dart';

class SettingsProvider with ChangeNotifier {
  bool _notificationsEnabled = true;
  double? _monthlyBudget;
  bool _isFirstLaunch = true;
  String? _geminiApiKey;
  
  // Theme mode: system (automatic), light, dark
  ThemeMode _themeMode = ThemeMode.system;

  bool get notificationsEnabled => _notificationsEnabled;
  double? get monthlyBudget => _monthlyBudget;
  bool get isFirstLaunch => _isFirstLaunch;
  String get geminiApiKey => _geminiApiKey ?? AppConstants.geminiApiKey;
  bool get hasCustomGeminiKey => _geminiApiKey != null && _geminiApiKey!.isNotEmpty;
  ThemeMode get themeMode => _themeMode;

  // Initialize settings from shared preferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    _notificationsEnabled = prefs.getBool(
      AppConstants.prefKeyNotificationsEnabled,
    ) ?? true;
    
    _monthlyBudget = prefs.getDouble(AppConstants.prefKeyMonthlyBudget);
    
    _isFirstLaunch = prefs.getBool(AppConstants.prefKeyFirstLaunch) ?? true;
    
    _geminiApiKey = prefs.getString(AppConstants.prefKeyGeminiApiKey);
    if (_geminiApiKey != null && _geminiApiKey!.isNotEmpty) {
      GeminiService.instance.setApiKey(_geminiApiKey);
    }

    final themeIndex = prefs.getInt('theme_mode_preference') ?? 0;
    if (themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    
    notifyListeners();
  }

  // Update Theme Mode (system / light / dark)
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode_preference', mode.index);
  }

  // Update Gemini API key
  Future<void> setGeminiApiKey(String? key) async {
    final trimmed = key?.trim();
    _geminiApiKey = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    GeminiService.instance.setApiKey(_geminiApiKey);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (_geminiApiKey != null) {
      await prefs.setString(AppConstants.prefKeyGeminiApiKey, _geminiApiKey!);
    } else {
      await prefs.remove(AppConstants.prefKeyGeminiApiKey);
    }
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
    _geminiApiKey = null;
    _themeMode = ThemeMode.system;
    GeminiService.instance.setApiKey(null);
    
    notifyListeners();
  }
}
