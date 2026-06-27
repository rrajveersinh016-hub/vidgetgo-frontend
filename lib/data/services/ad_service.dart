import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool isPremium = false;
  bool isFullScreenAdShowing = false;
  
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  int _interstitialRetryAttempts = 0;
  bool _showOnLoad = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  int _rewardedRetryAttempts = 0;

  DateTime? _lastFullScreenCloseTime;

  // AdMob Ad Unit IDs
  static const String _prodBannerAdId = 'ca-app-pub-1740051595604525/2661013463';
  static const String _testBannerAdId = 'ca-app-pub-3940256099942544/6300978111';

  static const String _prodInterstitialAdId = 'ca-app-pub-1740051595604525/1548838237';
  static const String _testInterstitialAdId = 'ca-app-pub-3940256099942544/1033173712';

  static const String _prodRewardedAdId = 'ca-app-pub-1740051595604525/2703329779';
  static const String _testRewardedAdId = 'ca-app-pub-3940256099942544/5224354917';

  String get bannerAdUnitId => kDebugMode ? _testBannerAdId : _prodBannerAdId;
  String get interstitialAdUnitId => kDebugMode ? _testInterstitialAdId : _prodInterstitialAdId;
  String get rewardedAdUnitId => kDebugMode ? _testRewardedAdId : _prodRewardedAdId;

  void setLastFullScreenCloseTime(DateTime time) {
    _lastFullScreenCloseTime = time;
  }

  bool get isCooldownSatisfied {
    if (_lastFullScreenCloseTime == null) return true;
    final elapsed = DateTime.now().difference(_lastFullScreenCloseTime!);
    return elapsed.inSeconds >= 5;
  }

  /// Updates the caching state. Called by HomeViewModel upon load/upgrade.
  void updatePremiumStatus(bool premium) {
    isPremium = premium;
    if (premium) {
      // Dispose ads if premium status is unlocked
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _rewardedAd?.dispose();
      _rewardedAd = null;
    }
  }

  /// Pre-loads the interstitial ad so it is ready to display immediately.
  void loadInterstitialAd() {
    if (isPremium || _isInterstitialAdLoading || _interstitialAd != null) return;
    _isInterstitialAdLoading = true;
    debugPrint("Interstitial: Start loading...");

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          _interstitialRetryAttempts = 0;
          debugPrint("Interstitial: Loaded successfully.");
          if (_showOnLoad) {
            _showOnLoad = false;
            showInterstitialAd();
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isInterstitialAdLoading = false;
          _showOnLoad = false;
          _interstitialRetryAttempts++;
          debugPrint("Interstitial: Failed to load: ${error.message} (code: ${error.code})");
          
          // Retry logic: if first interstitial fails, try again after 3 seconds
          if (_interstitialRetryAttempts <= 3) {
            debugPrint("Interstitial: Retrying load in 3 seconds (Attempt $_interstitialRetryAttempts)...");
            Future.delayed(const Duration(seconds: 3), () {
              loadInterstitialAd();
            });
          }
        },
      ),
    );
  }

  /// Shows the interstitial ad if loaded and is not premium.
  void showInterstitialAd({VoidCallback? onDismissed}) {
    if (isPremium) {
      if (onDismissed != null) onDismissed();
      return;
    }
    
    // Check conflicts:
    if (isFullScreenAdShowing) {
      debugPrint("Interstitial failed: Blocked - another fullscreen ad is showing.");
      if (onDismissed != null) onDismissed();
      return;
    }

    if (!isCooldownSatisfied) {
      debugPrint("Interstitial failed: Blocked - ad cooldown active.");
      if (onDismissed != null) onDismissed();
      return;
    }
    
    if (_interstitialAd != null) {
      debugPrint("Unity bidding request sent");
      debugPrint("Interstitial showing");
      
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          isFullScreenAdShowing = true;
          _lastFullScreenCloseTime = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint("Interstitial ad dismissed");
          isFullScreenAdShowing = false;
          _lastFullScreenCloseTime = DateTime.now();
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd(); // Load next one
          if (onDismissed != null) onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint("Interstitial failed: Failed to show: ${error.message}");
          isFullScreenAdShowing = false;
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd();
          if (onDismissed != null) onDismissed();
        },
      );
      _interstitialAd!.show();
    } else {
      debugPrint("Interstitial failed: Ad not ready. Initiating load...");
      loadInterstitialAd();
      if (onDismissed != null) onDismissed();
    }
  }

  /// Triggers loading/showing an ad on app startup.
  void showAppStartAd() {
    if (isPremium) return;
    if (_interstitialAd != null) {
      showInterstitialAd();
    } else {
      _showOnLoad = true;
      loadInterstitialAd();
    }
  }

  /// Cancels the startup ad if the user starts a download/process before it loads.
  void cancelAppStartAd() {
    _showOnLoad = false;
  }

  /// Pre-loads the rewarded ad.
  void loadRewardedAd() {
    if (isPremium || _isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;
    debugPrint("Rewarded: Start loading...");

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          _rewardedRetryAttempts = 0;
          debugPrint("Rewarded: Loaded successfully.");
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          _rewardedRetryAttempts++;
          debugPrint("Rewarded: Failed to load: ${error.message} (code: ${error.code})");
          
          // Retry logic: if rewarded ad fails, try again after 3 seconds
          if (_rewardedRetryAttempts <= 3) {
            debugPrint("Rewarded: Retrying load in 3 seconds (Attempt $_rewardedRetryAttempts)...");
            Future.delayed(const Duration(seconds: 3), () {
              loadRewardedAd();
            });
          }
        },
      ),
    );
  }

  /// Shows the rewarded ad and executes callbacks.
  void showRewardedAd({
    required VoidCallback onEarned,
    required VoidCallback onClosed,
    required Function(String) onError,
  }) {
    if (isFullScreenAdShowing) {
      debugPrint("Rewarded ad failed to show: another fullscreen ad is showing.");
      onError("Another ad is already showing. Please try again in a moment.");
      return;
    }

    if (!isCooldownSatisfied) {
      debugPrint("Rewarded ad failed to show: ad cooldown active.");
      onError("Please wait a few seconds before watching another ad.");
      return;
    }

    if (_rewardedAd != null) {
      debugPrint("Unity bidding request sent");
      debugPrint("Rewarded ad showing");
      
      bool earnedReward = false;

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          isFullScreenAdShowing = true;
          _lastFullScreenCloseTime = null;
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint("Rewarded ad dismissed");
          isFullScreenAdShowing = false;
          _lastFullScreenCloseTime = DateTime.now();
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          
          if (earnedReward) {
            onEarned();
          } else {
            onClosed();
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint("Rewarded ad failed: ${error.message}");
          isFullScreenAdShowing = false;
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          onError("Failed to display ad. Please try again.");
        },
      );
      
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          debugPrint("Rewarded ad reward granted");
          earnedReward = true;
        },
      );
    } else {
      debugPrint("Rewarded ad failed: Ad not ready. Initiating load...");
      loadRewardedAd();
      onError("Ad is loading. Please try again in a few seconds.");
    }
  }

  /// Builds a BannerAd widget wrapped in containment logic.
  Widget buildBannerAd() {
    if (isPremium) return const SizedBox.shrink();
    
    return _BannerAdWidget(adUnitId: bannerAdUnitId);
  }
}

class _BannerAdWidget extends StatefulWidget {
  final String adUnitId;
  const _BannerAdWidget({required this.adUnitId});

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    debugPrint("Banner ad loading initiated...");
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint("Banner ad loaded successfully.");
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint("Banner ad failed to load: ${err.message} (code: ${err.code})");
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdService().isPremium) {
      return const SizedBox.shrink();
    }

    // Wrap in a fixed 50px height container to ensure consistent rendering,
    // prevent layout shifting, and keep the banner visible at the bottom of the Downloads screen.
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.black,
      alignment: Alignment.center,
      child: _bannerAd != null && _isLoaded
          ? AdWidget(ad: _bannerAd!)
          : const SizedBox.shrink(),
    );
  }
}
