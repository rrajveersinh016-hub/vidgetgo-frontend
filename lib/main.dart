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
import 'data/services/remote_config_service.dart';
import 'data/services/ad_service.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Hive engine (synchronous memory setup is extremely fast)
    await Hive.initFlutter();
    Hive.registerAdapter(DownloadItemAdapter());
  } catch (e) {
    // debugPrint('Hive init error: $e');
  }

  // Initialize Mobile Ads SDK immediately (running in parallel)
  try {
    MobileAds.instance.initialize().then((InitializationStatus status) {
      // Log initialization status of each mediation adapter (Unity, Meta, etc.)
      // This is safe: if a single adapter fails, GMA continues with the others.
      status.adapterStatuses.forEach((adapterName, adapterStatus) {
        debugPrint(
          'Adapter [$adapterName]: '
          'state=${adapterStatus.state.name}, '
          'description=${adapterStatus.description}',
        );
      });

      // Preload ads ONLY after Google Mobile Ads SDK is fully initialized
      debugPrint("Google Mobile Ads SDK fully ready. Preloading ads...");
      AppOpenAdManager().init();
      AdService().loadInterstitialAd();
      AdService().loadRewardedAd();
    }).catchError((e) {
      debugPrint("Mobile Ads adapter initialization error: $e");
      // Fallback: load anyway if initialization fails (e.g. network timeout)
      AppOpenAdManager().init();
      AdService().loadInterstitialAd();
      AdService().loadRewardedAd();
    });
  } catch (e) {
    debugPrint("Mobile Ads initialization failed: $e");
    // Fallback
    AppOpenAdManager().init();
    AdService().loadInterstitialAd();
    AdService().loadRewardedAd();
  }
  
  runApp(
    const AppLifecycleReactor(
      child: LoopHoleApp(),
    ),
  );

  // Kick off non-critical initializations in the background
  _initNonCriticalServices();
}

Future<void> _initNonCriticalServices() async {
  try {
    // Initialize Firebase and Remote Config safely
    try {
      await Firebase.initializeApp();

      // Initialize Remote Config (maintenance mode, banners, backend URL)
      await RemoteConfigService().initialize();

      // Catch synchronous Flutter framework/widget errors
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exception.toString().contains('Failed to load font') ||
            details.exception.toString().contains('not found in the application assets')) {
          debugPrint('Font error caught: ${details.exception}');
          return; // silently ignore, use system font fallback
        }
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };

      // Catch asynchronous / background errors (network, isolates, etc.)
      PlatformDispatcher.instance.onError = (error, stack) {
        final errStr = error.toString();
        if (errStr.contains('Failed to load font') ||
            errStr.contains('firebase_remote_config') ||
            errStr.contains('Unable to connect to the server')) {
          debugPrint('Suppressed non-fatal background error: $error');
          return true; // silently ignore background network/font errors
        }
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase initialization failed (non-fatal): $e');
    }
  } catch (e) {
    debugPrint('Non-critical service init failed: $e');
    // never crash for non-critical services
  }
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AppOpenAdManager().appWentToBackground();
    } else if (state == AppLifecycleState.resumed) {
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
