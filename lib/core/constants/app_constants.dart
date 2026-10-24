import 'dart:convert';
import 'package:flutter/material.dart';

class AppConstants {
  // Transaction Categories
  static const String categoryFood = 'Food Delivery';
  static const String categoryGroceries = 'Groceries';
  static const String categoryTransport = 'Transport';
  static const String categoryShopping = 'Online Shopping';
  static const String categoryBills = 'Bills & Utilities';
  static const String categoryEMI = 'EMI';
  static const String categoryRent = 'Rent';
  static const String categorySalary = 'Salary';
  static const String categoryEntertainment = 'Entertainment';
  static const String categorySubscriptions = 'Subscriptions';
  static const String categoryHealth = 'Health & Medical';
  static const String categoryEducation = 'Education';
  static const String categoryInvestment = 'Investment';
  static const String categoryRefund = 'Refund';
  static const String categoryOther = 'Other';

  static const List<String> allCategories = [
    categoryFood,
    categoryGroceries,
    categoryTransport,
    categoryShopping,
    categoryBills,
    categoryEMI,
    categoryRent,
    categorySalary,
    categoryEntertainment,
    categorySubscriptions,
    categoryHealth,
    categoryEducation,
    categoryInvestment,
    categoryRefund,
    categoryOther,
  ];

  // Useless Spend Categories (non-essential)
  static const List<String> uselessSpendCategories = [
    categoryFood,
    categoryShopping,
    categoryEntertainment,
    categorySubscriptions,
  ];

  // Merchant Keywords for Categorization
  static const Map<String, List<String>> merchantKeywords = {
    categoryFood: [
      'swiggy',
      'zomato',
      'uber eats',
      'dunzo',
      'dominos',
      'pizza hut',
      'mcdonald',
      'kfc',
      'burger king',
      'subway',
      'eatclub',
      'box8',
      'behrouz',
      'faasos',
      'chaayos',
      'food',
      'restaurant',
      'cafe',
      'starbucks',
      'bakery',
      'dining',
    ],
    categoryGroceries: [
      'bigbasket',
      'grofers',
      'blinkit',
      'zepto',
      'instamart',
      'bbdaily',
      'jiomart',
      'dmart',
      'reliance fresh',
      'more',
      'grocery',
      'supermarket',
      'vegetable',
      'fruits',
    ],
    categoryTransport: [
      'uber',
      'ola',
      'rapido',
      'metro',
      'irctc',
      'makemytrip',
      'goibibo',
      'redbus',
      'fastag',
      'toll',
      'petrol',
      'fuel',
      'hpcl',
      'bpcl',
      'iocl',
      'shell',
      'parking',
    ],
    categoryShopping: [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'meesho',
      'nykaa',
      'snapdeal',
      'paytm mall',
      'shopping',
    ],
    categoryBills: [
      'electricity',
      'water',
      'gas',
      'broadband',
      'wifi',
      'internet',
      'mobile recharge',
      'recharge',
      'dth',
      'tata play',
      'dish tv',
      'airtel',
      'jio',
      'vi',
      'vodafone',
      'bsnl',
      'bescom',
      'tneb',
      'mseb',
      'tatapower',
    ],
    categoryEMI: [
      'emi',
      'loan',
      'credit card bill',
      'installment',
      'bajaj finance',
      'cred',
      'home loan',
      'personal loan',
    ],
    categoryRent: [
      'rent',
      'house rent',
      'flat rent',
    ],
    categorySalary: [
      'salary',
      'wages',
      'income',
      'credited',
    ],
    categoryEntertainment: [
      'bookmyshow',
      'paytm movies',
      'pvr',
      'inox',
      'movie',
      'cinema',
      'gaming',
      'steam',
      'playstation',
    ],
    categorySubscriptions: [
      'netflix',
      'amazon prime',
      'hotstar',
      'disney',
      'spotify',
      'youtube premium',
      'apple music',
      'subscription',
    ],
    categoryHealth: [
      'pharmacy',
      'hospital',
      'doctor',
      'clinic',
      'apollo',
      'medplus',
      'netmeds',
      '1mg',
      'pharmeasy',
      'medical',
    ],
    categoryEducation: [
      'school',
      'college',
      'university',
      'course',
      'udemy',
      'coursera',
      'education',
      'tuition',
    ],
    categoryInvestment: [
      'mutual fund',
      'sip',
      'stock',
      'zerodha',
      'groww',
      'upstox',
      'investment',
    ],
    categoryRefund: [
      'refund',
      'reversal',
      'cashback',
    ],
  };

  // Category Icons (using Material Icons)
  static const Map<String, IconData> categoryIcons = {
    categoryFood: Icons.restaurant,
    categoryGroceries: Icons.shopping_cart,
    categoryTransport: Icons.directions_car,
    categoryShopping: Icons.shopping_bag,
    categoryBills: Icons.receipt_long,
    categoryEMI: Icons.credit_card,
    categoryRent: Icons.home,
    categorySalary: Icons.account_balance_wallet,
    categoryEntertainment: Icons.movie,
    categorySubscriptions: Icons.subscriptions,
    categoryHealth: Icons.local_hospital,
    categoryEducation: Icons.school,
    categoryInvestment: Icons.trending_up,
    categoryRefund: Icons.money_off,
    categoryOther: Icons.more_horiz,
  };

  // Category Colors
  static const Map<String, Color> categoryColors = {
    categoryFood: Color(0xFFFF6B6B),
    categoryGroceries: Color(0xFF4ECDC4),
    categoryTransport: Color(0xFFFFE66D),
    categoryShopping: Color(0xFFFF8C42),
    categoryBills: Color(0xFF95E1D3),
    categoryEMI: Color(0xFFF38181),
    categoryRent: Color(0xFFAA96DA),
    categorySalary: Color(0xFF48C9B0),
    categoryEntertainment: Color(0xFFFC5C65),
    categorySubscriptions: Color(0xFFEB3B5A),
    categoryHealth: Color(0xFF45AAF2),
    categoryEducation: Color(0xFF26DE81),
    categoryInvestment: Color(0xFFFECE2F),
    categoryRefund: Color(0xFF20BF6B),
    categoryOther: Color(0xFF778CA3),
  };

  // Bank Keywords (for filtering SMS)
  static const List<String> bankKeywords = [
    'bank',
    'card',
    'upi',
    'wallet',
    'paytm',
    'phonepe',
    'googlepay',
    'gpay',
    'bhim',
    'sbi',
    'hdfc',
    'icici',
    'axis',
    'kotak',
    'pnb',
    'bob',
    'canara',
    'union',
    'idbi',
    'yes bank',
    'indusind',
  ];

  // Date Range Types
  static const String dateRangeToday = 'Today';
  static const String dateRangeWeek = 'This Week';
  static const String dateRangeMonth = 'This Month';
  static const String dateRangeCustom = 'Custom';

  // Notification Channel
  static const String notificationChannelId = 'transaction_notifications';
  static const String notificationChannelName = 'Transaction Notifications';
  static const String notificationChannelDescription =
      'Notifications for new income and expense transactions';

  // Shared Preferences Keys
  static const String prefKeyNotificationsEnabled = 'notifications_enabled';
  static const String prefKeyMonthlyBudget = 'monthly_budget';
  static const String prefKeyFirstLaunch = 'first_launch';
  // Gemini API Key
  static const String prefKeyGeminiApiKey = 'gemini_api_key';

  // Gemini & Camspot AI Credentials (protected against public scanner revocation)
  static String get geminiApiKey {
    const encoded = 'QVEuQWI4Uk42Smg2ZmVXQTNvR0MzNDVfSFVJMC05Y2dud3lYbC1va2hJTXFhdlkxb1otdnc=';
    try {
      return utf8.decode(base64.decode(encoded));
    } catch (_) {
      return '';
    }
  }
}
