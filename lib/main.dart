import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/finance_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/account_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/recurring_provider.dart';
import 'providers/security_provider.dart';
import 'providers/notification_sync_provider.dart';
import 'providers/notification_settings_provider.dart';
import 'providers/goal_provider.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/security/lock_screen.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final SecurityProvider _securityProvider;
  bool _isSplashDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _securityProvider = SecurityProvider()..loadSecuritySettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _securityProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_securityProvider.isAutoLockEnabled && _securityProvider.isSecurityConfigured) {
        _securityProvider.lockApp();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _securityProvider),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()..loadCurrency()),
        ChangeNotifierProvider(create: (_) => AccountProvider()..loadAccounts()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()..loadBudgets()),
        ChangeNotifierProvider(create: (_) => RecurringProvider()..loadRecurring()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()..loadDebts()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadPreference()),
        ChangeNotifierProvider(create: (_) => NotificationSyncProvider()),
        ChangeNotifierProvider(create: (_) => NotificationSettingsProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()..loadGoals()),
      ],
      child: Consumer2<ThemeProvider, SecurityProvider>(
        builder: (context, themeProvider, securityProvider, _) {
          return MaterialApp(
            title: 'My Money',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeProvider.themeMode,
            builder: (context, child) {
              return Stack(
                children: [
                  if (child != null) child,
                  if (securityProvider.isInitialized &&
                      securityProvider.isAppLocked &&
                      _isSplashDone)
                    const Positioned.fill(
                      child: LockScreen(mode: LockScreenMode.unlock),
                    ),
                ],
              );
            },
            home: SplashScreen(
              onFinished: () {
                if (mounted) {
                  setState(() {
                    _isSplashDone = true;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }
}
