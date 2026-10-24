# FinTracker - SMS-Based Finance Manager

A Flutter Android app that automatically tracks your income and expenses by reading and parsing bank SMS messages. Get real-time financial insights, spending analytics, and personalized tips to manage your money better.

## Features

### 🔄 Automatic Transaction Tracking
- Reads bank SMS messages automatically
- Parses transactions from multiple banks (SBI, HDFC, ICICI, Axis, Kotak, etc.)
- Supports various transaction types: UPI, card payments, ATM, NEFT, IMPS
- Real-time sync when new SMS arrives

### 📊 Smart Categorization
- Automatically categorizes transactions into:
  - Food Delivery, Groceries, Transport, Shopping
  - Bills & Utilities, EMI, Rent, Salary
  - Entertainment, Subscriptions, Health, Education
  - Investment, Refunds, and more
- Identifies "useless spends" (non-essential expenses)

### 💡 Financial Insights
- Daily/Weekly/Monthly summaries
- Total income, expense, and balance
- Useless spend tracking with percentage
- Spending trends over 6 months
- Personalized insights like:
  - "You spent 30% more this month"
  - "Your top category: Food (₹5,240)"
  - "Savings rate is only 15%. Try to save more!"

### 📈 Analytics & Visualization
- Pie chart for category breakdown
- Bar chart for monthly spending trends
- Biggest expense tracking
- Top spending category

### 🔔 Smart Notifications
- Get notified for new transactions
- Income: "💰 Income: ₹50,000 from Salary"
- Expense: "💸 Expense: ₹799 on Food at Zomato"

### 🔒 Privacy First
- All data stays on your device
- No cloud sync (in MVP)
- No external servers
- SMS content never leaves your phone

## Screenshots

_Coming soon_

## Installation

### Prerequisites
- Flutter SDK (3.10.0 or higher)
- Android Studio or VS Code with Flutter extension
- Android device or emulator (API 21+)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd fin_tracker
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

## Permissions

The app requires the following permissions:

- **READ_SMS**: To read existing bank SMS messages
- **RECEIVE_SMS**: To listen for new incoming SMS
- **POST_NOTIFICATIONS**: To show transaction notifications (Android 13+)

All permissions are requested at runtime with clear explanations.

## Architecture

The app follows **Clean Architecture** with **MVVM** pattern:

```
lib/
├── core/               # Constants, utilities, theme
├── data/               # Models, database, repositories
├── services/           # Business logic (SMS, parsing, analytics)
├── providers/          # State management (Provider)
└── ui/                 # Screens and widgets
```

### Key Components

1. **Data Layer**
   - `TransactionModel`: Core data model
   - `DatabaseHelper`: SQLite database setup
   - `TransactionDao`: Database operations
   - `TransactionRepository`: Data access abstraction

2. **Services Layer**
   - `SmsService`: SMS reading and listening
   - `ParserService`: SMS parsing with regex
   - `CategorizationService`: Auto-categorization
   - `AnalyticsService`: Financial calculations
   - `NotificationService`: Local notifications

3. **Providers (State Management)**
   - `TransactionProvider`: Transaction state
   - `AnalyticsProvider`: Analytics state
   - `SettingsProvider`: App settings

4. **UI Layer**
   - `OnboardingScreen`: First-time setup
   - `DashboardScreen`: Main summary view
   - `TransactionsScreen`: Transaction list
   - `AnalyticsScreen`: Charts and insights
   - `SettingsScreen`: App configuration

## Usage

### First Launch
1. Grant SMS permissions when prompted
2. App will sync existing bank SMS (last 100 messages)
3. View your financial summary on the dashboard

### Dashboard
- Toggle between Today/Week/Month views
- See income, expense, balance, and useless spends
- View insights and recent transactions
- Pull to refresh or tap sync button

### Transactions
- View all transactions with filters
- Filter by type (Income/Expense)
- Filter by category
- Search and sort

### Analytics
- View spending by category (pie chart)
- See monthly trends (bar chart)
- Read personalized insights

### Settings
- Enable/disable notifications
- Set monthly budget
- Re-sync SMS messages
- Clear all data

## SMS Parsing

The app uses regex patterns to parse various SMS formats:

### Supported Banks
- State Bank of India (SBI)
- HDFC Bank
- ICICI Bank
- Axis Bank
- Kotak Mahindra Bank
- Punjab National Bank (PNB)
- And more...

### Supported Wallets/UPI
- Paytm
- PhonePe
- Google Pay
- BHIM

### Example SMS Formats

**Debit:**
```
INR 500 debited from a/c XXXX1234 on 21-11-2025 at Amazon
Rs. 799.00 spent on your card XX1234 at Zomato
```

**Credit:**
```
INR 50,000 credited to your a/c XXXX1234
Salary of Rs. 45,000 has been credited
```

**UPI:**
```
UPI transaction of Rs. 250 to merchant@paytm
You received Rs. 1000 from friend@oksbi via UPI
```

## Customization

### Adding New Categories
Edit `lib/core/constants/app_constants.dart`:
```dart
static const String categoryNewCategory = 'New Category';
```

### Adding Keywords for Categorization
Update merchant keywords in `app_constants.dart`:
```dart
categoryNewCategory: [
  'keyword1',
  'keyword2',
  'merchant_name',
],
```

### Adding Bank Patterns
Update `lib/core/constants/sms_patterns.dart`:
```dart
'BankName': [
  RegExp(r'bank_pattern', caseSensitive: false),
],
```

## Future Enhancements

### Planned Features
- [ ] AI-based categorization using ML
- [ ] Export to CSV/Excel
- [ ] Budget alerts and warnings
- [ ] Cloud sync with encryption
- [ ] Manual transaction entry
- [ ] Recurring transaction detection
- [ ] Bill payment reminders
- [ ] Multi-language support
- [ ] Dark mode
- [ ] Widgets for home screen

## Testing

### Unit Tests
```bash
flutter test
```

### Manual Testing
1. Send test SMS messages to your device
2. Verify parsing accuracy
3. Check categorization
4. Validate analytics calculations

## Troubleshooting

### SMS Not Being Parsed
- Check if sender is a known bank
- Verify SMS contains amount and transaction keywords
- Check logs for parsing errors

### Permissions Denied
- Go to Settings > Apps > FinTracker > Permissions
- Enable SMS and Notifications manually

### Transactions Not Syncing
- Pull to refresh on dashboard
- Tap sync button in settings
- Check if SMS permission is granted

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Disclaimer

This app is for personal use only. It reads SMS messages locally and does not send data to any external servers. Use at your own discretion. The developers are not responsible for any financial decisions made based on the app's insights.

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Contact: [your-email@example.com]

---

**Made with ❤️ using Flutter**
