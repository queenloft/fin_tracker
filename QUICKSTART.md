# FinTracker - Quick Start Guide

## What Was Built

A complete Flutter Android app for automatic expense tracking via SMS parsing.

## Project Structure

```
d:/flutter/fin_tracker/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── core/                        # Constants, utils, theme
│   ├── data/                        # Models, database, repositories
│   ├── services/                    # Business logic
│   ├── providers/                   # State management
│   └── ui/                          # Screens & widgets
├── android/                         # Android configuration
├── pubspec.yaml                     # Dependencies
└── README.md                        # Documentation
```

## Running the App

### 1. Install Dependencies
```bash
cd d:/flutter/fin_tracker
flutter pub get
```

### 2. Connect Android Device
- Enable USB debugging
- Connect via USB or use emulator

### 3. Run the App
```bash
flutter run
```

### 4. First Launch
- Grant SMS permission when prompted
- App will sync existing bank SMS
- View dashboard with financial summary

## Key Features

✅ Automatic SMS reading and parsing
✅ Smart transaction categorization  
✅ Real-time financial insights
✅ Daily/Weekly/Monthly summaries
✅ Useless spend tracking
✅ Analytics with charts
✅ Local notifications
✅ Privacy-first (all data on device)

## Testing

### Test with Sample SMS
Send these SMS to your device:

**Debit:**
```
INR 500 debited from a/c XXXX1234 on 21-11-2025 at Amazon
```

**Credit:**
```
INR 50,000 credited to your a/c XXXX1234 Salary
```

### Verify
1. Check if transaction appears in dashboard
2. Verify categorization is correct
3. Check analytics charts
4. Test notifications

## Troubleshooting

### Dependencies Not Installing
```bash
flutter clean
flutter pub get
```

### Build Errors
```bash
flutter doctor
flutter pub get
flutter run
```

### SMS Not Parsing
- Ensure SMS permission is granted
- Check if sender is a known bank
- Pull to refresh on dashboard

## Next Steps

1. **Test with Real SMS**: Use your actual bank SMS
2. **Customize Categories**: Edit `app_constants.dart`
3. **Add More Banks**: Update `sms_patterns.dart`
4. **Deploy**: Build APK for distribution

## Build APK

```bash
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

---

**Ready to use!** 🚀
