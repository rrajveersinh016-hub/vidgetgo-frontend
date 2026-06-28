import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'app.dart';
import 'data/models/download_item.dart';
import 'data/services/app_open_ad_manager.dart';
import 'data/services/update_checker.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely — app will not crash even if this fails
  try {
    await Firebase.initializeApp();

    // Catch synchronous Flutter framework/widget errors
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Catch asynchronous / background errors (network, isolates, etc.)
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Firebase initialization failed (non-fatal): $e');
  }

  try {
    // Initialize Hive engine (synchronous memory setup is extremely fast)
    await Hive.initFlutter();
    Hive.registerAdapter(DownloadItemAdapter());
  } catch (e) {
    // debugPrint('Hive init error: $e');
  }
  
  runApp(
    const AppLifecycleReactor(
      child: LoopHoleApp(),
    ),
  );

  // Initialize Mobile Ads SDK and App Open Ad Manager in the background
  MobileAds.instance.initialize().then((_) {
    AppOpenAdManager().init();
  });
}

class AppLifecycleReactor extends StatefulWidget {
  final Widget child;
  const AppLifecycleReactor({super.key, required this.child});

  @override
  State<AppLifecycleReactor> createState() => _AppLifecycleReactorState();
}

class _AppLifecycleReactorState extends State<AppLifecycleReactor> with WidgetsBindingObserver {
  bool _updateCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pre-load the first App Open Ad immediately on app launch
    AppOpenAdManager().loadAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppOpenAdManager().showAdIfAvailable();
      if (!_updateCheckDone) {
        UpdateChecker.checkForUpdate(scaffoldMessengerKey);
        _updateCheckDone = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
