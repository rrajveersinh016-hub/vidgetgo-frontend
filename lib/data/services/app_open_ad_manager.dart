import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'ad_service.dart';

class AppOpenAdManager {
  static final AppOpenAdManager _instance = AppOpenAdManager._internal();
  factory AppOpenAdManager() => _instance;
  AppOpenAdManager._internal();

  AppOpenAd? _appOpenAd;
  bool _isLoadingAd = false;
  bool _isShowingAd = false;
  bool _isColdStart = true;
  DateTime? _lastShowTime;
  DateTime? _backgroundTime;
  final DateTime _appLaunchTime = DateTime.now();

  bool isSplashActive = false;
  VoidCallback? onSplashAdDismissed;

  bool get isAdAvailable => _appOpenAd != null;

  void appWentToBackground() {
    _backgroundTime = DateTime.now();
    debugPrint("App Open: App went to background at $_backgroundTime");
  }

  static const String _prodAdUnitId = 'ca-app-pub-1740051595604525/7936570035';
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/5677595818';

  String get adUnitId => _prodAdUnitId;

  /// Check frequency cap (at least 4 hours since the last ad show)
  bool get _isFrequencyCapSatisfied {
    if (_lastShowTime == null) return true;
    final difference = DateTime.now().difference(_lastShowTime!);
    return difference.inMinutes >= 5;
  }

  /// Loads the persisted show time from SharedPreferences.
  Future<void> init() async {
    await _loadLastShowTime();
    loadAd();
  }

  Future<void> _loadLastShowTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt('app_open_last_show_time') ?? 0;
      if (millis > 0) {
        _lastShowTime = DateTime.fromMillisecondsSinceEpoch(millis);
        debugPrint("App Open: Loaded last show time: $_lastShowTime");
      }
    } catch (e) {
      debugPrint("App Open: Error loading last show time: $e");
    }
  }

  Future<void> _saveLastShowTime(DateTime time) async {
    try {
      _lastShowTime = time;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('app_open_last_show_time', time.millisecondsSinceEpoch);
      debugPrint("App Open: Saved last show time: $time");
    } catch (e) {
      debugPrint("App Open: Error saving last show time: $e");
    }
  }

  /// Loads an App Open Ad.
  void loadAd() {
    if (AdService().isPremium || _isLoadingAd || _appOpenAd != null) return;
    _isLoadingAd = true;
    debugPrint("App Open loading");

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isLoadingAd = false;
          debugPrint("App Open: Loaded successfully.");
          if (isSplashActive) {
            showAdIfAvailable();
          } else if (_isColdStart) {
            _isColdStart = false;
            final elapsed = DateTime.now().difference(_appLaunchTime);
            if (elapsed.inSeconds <= 5) {
              showAdIfAvailable();
            } else {
              debugPrint("App Open: Cold start ad loaded too late (${elapsed.inSeconds}s), keeping in cache.");
            }
          }
        },
        onAdFailedToLoad: (error) {
          _isLoadingAd = false;
          _appOpenAd = null;
          debugPrint("App Open unavailable: ${error.message} (code: ${error.code})");
          Future.delayed(const Duration(seconds: 30), () => loadAd());
        },
      ),
    );
  }

  /// Shows the ad if available and not blocked by frequency capping or active fullscreen ads.
  void showAdIfAvailable() {
    debugPrint("App Open: showAdIfAvailable called.");

    if (AdService().isPremium) {
      debugPrint("App Open: Skipped - user is premium.");
      if (isSplashActive) {
        isSplashActive = false;
        if (onSplashAdDismissed != null) onSplashAdDismissed!();
      }
      return;
    }

    if (_isShowingAd) {
      debugPrint("App Open: Skipped - ad already showing.");
      return;
    }

    if (AdService().isFullScreenAdShowing) {
      debugPrint("App Open: Skipped - another fullscreen ad is showing (Priority: Interstitial/Rewarded > App Open).");
      if (isSplashActive) {
        isSplashActive = false;
        if (onSplashAdDismissed != null) onSplashAdDismissed!();
      }
      return;
    }

    if (!AdService().isCooldownSatisfied) {
      debugPrint("App Open: Skipped - ad cooldown active.");
      if (isSplashActive) {
        isSplashActive = false;
        if (onSplashAdDismissed != null) onSplashAdDismissed!();
      }
      return;
    }

    if (!_isFrequencyCapSatisfied) {
      debugPrint("App Open: Skipped - frequency cap not satisfied. Last show time: $_lastShowTime");
      if (isSplashActive) {
        isSplashActive = false;
        if (onSplashAdDismissed != null) onSplashAdDismissed!();
      }
      return;
    }

    if (_backgroundTime != null) {
      final elapsed = DateTime.now().difference(_backgroundTime!);
      _backgroundTime = null;
      if (elapsed.inSeconds < 30) {
        debugPrint("App Open: Skipped - app in background for less than 30s (${elapsed.inSeconds}s).");
        if (isSplashActive) {
          isSplashActive = false;
          if (onSplashAdDismissed != null) onSplashAdDismissed!();
        }
        return;
      }
    }

    if (_appOpenAd == null) {
      debugPrint("App Open: Ad not ready. Triggering reload...");
      loadAd();
      if (isSplashActive) {
        isSplashActive = false;
        if (onSplashAdDismissed != null) onSplashAdDismissed!();
      }
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        AdService().isFullScreenAdShowing = true;
        debugPrint("App Open showing");
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint("App Open: Dismissed.");
        ad.dispose();
        _appOpenAd = null;
        _isShowingAd = false;
        AdService().isFullScreenAdShowing = false;
        AdService().setLastFullScreenCloseTime(DateTime.now());
        _saveLastShowTime(DateTime.now());
        loadAd(); // Preload the next ad
        if (isSplashActive) {
          isSplashActive = false;
          if (onSplashAdDismissed != null) onSplashAdDismissed!();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint("App Open: Failed to show: ${error.message}");
        ad.dispose();
        _appOpenAd = null;
        _isShowingAd = false;
        AdService().isFullScreenAdShowing = false;
        loadAd();
        if (isSplashActive) {
          isSplashActive = false;
          if (onSplashAdDismissed != null) onSplashAdDismissed!();
        }
      },
    );

    debugPrint("Unity bidding request sent");
    try {
      _appOpenAd!.show();
    } on PlatformException catch (e) {
      debugPrint('App Open ad failed to show (PlatformException): $e');
      if (isSplashActive) {
        isSplashActive = false;
        if (onSplashAdDismissed != null) onSplashAdDismissed!();
      }
    } catch (e) {
      debugPrint('App Open ad show error: $e');
      if (isSplashActive) {
        isSplashActive = false;
        if (onSplashAdDismissed != null) onSplashAdDismissed!();
      }
    }
  }
}
