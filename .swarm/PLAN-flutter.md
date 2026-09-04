# DaliDeck Flutter App Build Plan — 3 Features

## FEATURE 1: Remove Money Info from TodayView

### File: lib/ui/today.dart
- Delete money computation block (ym, inM, outM, wallet, cur variables)
- Delete two _Metric widgets for this_month and wallet
- Keep all other metrics (days, exam, lessons, tasks, revision)

## FEATURE 2: PIN Tab Lock

### New files:
- lib/services/pin_service.dart — SHA-256 hash/verify
- lib/ui/pin_screen.dart — PIN entry lock screen

### Modified files:
- lib/models.dart — Add privacyLock to AppState, session unlock to Store
- lib/ui/home.dart — Intercept tab nav for locked tabs
- lib/ui/more.dart — Intercept sub-screen nav for locked pages
- lib/ui/settings.dart — Privacy Lock section with PIN management
- lib/i18n.dart — New EN/AR strings
- pubspec.yaml — Add crypto: ^3.0.3

### State schema:
```dart
Map<String, dynamic> privacyLock = {
  'enabled': false,
  'tabs': {'money':false, 'habits':false, 'notes':false, 'projects':false, 'quran':false, 'focus':false, 'review':false, 'school':false},
  'pinHash': null,
};
```

### Store session unlock:
```dart
final Set<String> _unlockedTabs = {};
bool isTabUnlocked(String tabId) => _unlockedTabs.contains(tabId);
void unlockTab(String tabId) => _unlockedTabs.add(tabId);
```

### PIN screen:
- Numeric keypad (3x4 grid), animated dots, error text
- 5 failed attempts → 30s lockout
- Uses hashPin/verifyPin from pin_service

## FEATURE 3: Tab Layout Customization

### Modified files:
- lib/models.dart — Add tabLayout to AppState
- lib/ui/home.dart — Dynamic nav bar from tabLayout
- lib/ui/settings.dart — Tab Layout section with toggle/reorder
- lib/i18n.dart — New strings

### State schema:
```dart
List<Map<String, dynamic>> tabLayout = [
  {'id':'today','visible':true}, {'id':'school','visible':true},
  {'id':'money','visible':true}, {'id':'more','visible':true},
  {'id':'settings','visible':true},
  // others hidden by default
];
```

### visibleTabIds() utility function

### Dynamic NavigationBar built from visible tabs

### Settings section with up/down arrows and visibility toggles