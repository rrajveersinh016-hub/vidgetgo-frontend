import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/platform_detector.dart';
import '../../core/utils/url_validator.dart';
import '../../core/utils/network_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/download_item.dart';
import '../../data/repositories/download_repository.dart';
import '../../data/services/downloader_service.dart';
import '../../data/services/ad_service.dart';
import '../widgets/loophole_button.dart'; // for LoopHoleState

import 'package:google_fonts/google_fonts.dart';

class HomeViewModel extends ChangeNotifier {
  final DownloaderService _downloader = DownloaderService();
  final DownloadRepository _repo = DownloadRepository();
  final AdService _adService = AdService();
  
  bool isPremium = false;
  bool _isProcessing = false;
  int adsWatchedCount = 0;
  DateTime? proExpiryDate;


  HomeViewModel() {
    loadPremiumState();
  }

  /// Expose method to load startup ads.
  void showAppStartAd() {
    _adService.showAppStartAd();
  }

  Future<void> loadPremiumState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check expiry
    final expiryStr = prefs.getString('pro_expiry_timestamp');
    if (expiryStr != null) {
      proExpiryDate = DateTime.tryParse(expiryStr);
      if (proExpiryDate != null && DateTime.now().isBefore(proExpiryDate!)) {
        isPremium = true;
      } else {
        isPremium = false;
        proExpiryDate = null;
      }
    } else {
      isPremium = false;
      proExpiryDate = null;
    }
    
    // Load count
    adsWatchedCount = prefs.getInt('ads_watched_count') ?? 0;

    _adService.updatePremiumStatus(isPremium);
    if (!isPremium) {
      _adService.loadInterstitialAd();
      _adService.loadRewardedAd();
    }
    notifyListeners();
  }

  Future<void> watchRewardedAd(BuildContext context) async {
    final completer = Completer<void>();
    
    _adService.showRewardedAd(
      onEarned: () async {
        adsWatchedCount++;
        final prefs = await SharedPreferences.getInstance();
        
        if (adsWatchedCount >= 5) {
          // Grant 2 days of Pro
          final expiry = DateTime.now().add(const Duration(days: 2));
          proExpiryDate = expiry;
          await prefs.setString('pro_expiry_timestamp', expiry.toIso8601String());
          await prefs.setInt('ads_watched_count', 0);
          adsWatchedCount = 0;
          isPremium = true;
          _adService.updatePremiumStatus(true);
        } else {
          await prefs.setInt('ads_watched_count', adsWatchedCount);
          final remaining = 5 - adsWatchedCount;
          if (context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ad completed! Watch $remaining more to unlock Premium.'),
                backgroundColor: Colors.blueAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
      onClosed: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please finish watching for reward'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (!completer.isCompleted) completer.complete();
      },
      onError: (errorMsg) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red[800],
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (!completer.isCompleted) completer.complete();
      },
    );
    
    return completer.future;
  }

  Future<void> setPremium(bool val) async {
    isPremium = val;
    final prefs = await SharedPreferences.getInstance();
    if (val) {
      final expiry = DateTime.now().add(const Duration(days: 2));
      proExpiryDate = expiry;
      await prefs.setString('pro_expiry_timestamp', expiry.toIso8601String());
    } else {
      proExpiryDate = null;
      await prefs.remove('pro_expiry_timestamp');
    }
    _adService.updatePremiumStatus(val);
    notifyListeners();
  }
  
  LoopHoleState logoState = LoopHoleState.idle;
  double downloadProgress = 0.0;
  String detectedPlatform = '';
  String errorMessage = '';
  bool showPlatformBadge = false;


  Future<bool?> _showFormatSelectionSheet(BuildContext context, String title) async {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F0F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(color: Color(0xFF8B00FF), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'DOWNLOAD OPTIONS',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.video_library_rounded, color: Color(0xFF8B00FF)),
                title: const Text('Video + Audio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Download full video in high quality', style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF8B00FF)),
                onTap: () => Navigator.pop(ctx, false), // Video + Audio
              ),
              const Divider(color: Color(0xFF1F1F1F)),
              ListTile(
                leading: const Icon(Icons.audiotrack_rounded, color: Color(0xFF8B00FF)),
                title: const Text('Audio Only', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Fast download, less data usage (M4A)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, true), // Audio Only
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> onCircleTapped({String? manualUrl, Function(String)? onError, BuildContext? context}) async {
    if (_isProcessing || logoState == LoopHoleState.downloading) return;
    _isProcessing = true;

    // Safety timeout to prevent stuck state
    Future.delayed(const Duration(seconds: 60), () {
      if (_isProcessing) {
        _isProcessing = false;
        if (logoState == LoopHoleState.downloading) {
          logoState = LoopHoleState.idle;
          notifyListeners();
        }
      }
    });



    try {
      // Pre-flight network verification
      final hasNet = await NetworkChecker.hasInternet();
      if (!hasNet) {
        _setError('NO INTERNET CONNECTION', onError);
        _isProcessing = false;
        return;
      }
      
      String url;
      if (manualUrl != null && manualUrl.isNotEmpty) {
        url = manualUrl.trim();
      } else {
        final ClipboardData? data = await Clipboard.getData('text/plain');
        url = data?.text?.trim() ?? '';
      }
      
      if (url.isEmpty || !isValidUrl(url)) {
        _setError(manualUrl != null ? 'Invalid shared link' : 'No valid link in clipboard', onError);
        _isProcessing = false;
        return;
      }
      
      // Detect platform
      final platform = detectPlatform(url);
      if (platform == PlatformType.unknown) {
        _setError('Platform not supported', onError);
        _isProcessing = false;
        return;
      }

      // Preemptive block for photos/carousels (urls containing /p/)
      if (url.contains('/p/')) {
        _setError('PHOTOS_NOT_SUPPORTED', onError);
        _isProcessing = false;
        return;
      }
      
      // Check duplicate
      final isDup = await _repo.isDuplicate(url);
      if (isDup) {
        errorMessage = 'Already downloaded';
      } else {
        errorMessage = '';
      }
      
      void startDownloadFlow() async {
        DownloadItem? currentItem;
        try {
          detectedPlatform = platformName(platform);
          showPlatformBadge = true;
          HapticFeedback.vibrate();
          logoState = LoopHoleState.downloading;
          downloadProgress = 0.0;
          notifyListeners();

          // Fetch media info — returns a single Map
          final Map<String, dynamic> info =
              await _downloader.fetchVideoInfo(url).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Timed out. Please try again.');
            },
          );

          final bool isPhotoMedia =
              (info['media_type'] as String? ?? '') == 'photo';
          bool audioOnly = false;

          if (!isPhotoMedia && context != null && context.mounted) {
            // Show format selection for video content
            logoState = LoopHoleState.idle;
            notifyListeners();

            final chosenAudioOnly =
                await _showFormatSelectionSheet(context, info['title'] as String? ?? 'Media');
            if (chosenAudioOnly == null) {
              // Cancelled
              logoState = LoopHoleState.idle;
              showPlatformBadge = false;
              detectedPlatform = '';
              _isProcessing = false;
              notifyListeners();
              return;
            }
            audioOnly = chosenAudioOnly;

            logoState = LoopHoleState.downloading;
            notifyListeners();
          }

          // Per-item extension
          final String extension =
              isPhotoMedia ? 'jpg' : (audioOnly ? 'm4a' : 'mp4');
          final String filename =
              'Media_${DateTime.now().millisecondsSinceEpoch}.$extension';

          // Save to DB immediately
          currentItem = DownloadItem()
            ..id = DateTime.now().millisecondsSinceEpoch.toString()
            ..url = url
            ..title = info['title'] as String? ?? filename
            ..platform = detectedPlatform
            ..quality = isPhotoMedia
                ? 'Photo'
                : (audioOnly ? 'Audio' : (info['quality'] as String? ?? 'max'))
            ..filePath = ''
            ..thumbnailUrl = info['thumbnail'] as String? ?? ''
            ..status = DownloadItem.downloading
            ..fileSize = 0
            ..createdAt = DateTime.now();
          await _repo.save(currentItem);

          // Download with progress
          final filePath = await _downloader.downloadFile(
            info['url'] as String,
            info['title'] as String? ?? (isPhotoMedia ? 'photo' : 'video'),
            detectedPlatform,
            (progress) {
              downloadProgress = progress;
              notifyListeners();
            },
            audioOnly: isPhotoMedia ? false : audioOnly,
            isPhoto: isPhotoMedia,
          );

          // Update DB with completed status
          final File savedFile = File(filePath);
          if (await savedFile.exists()) {
            currentItem.fileSize = await savedFile.length();
          }
          currentItem.filePath = filePath;
          currentItem.status = DownloadItem.completed;
          await _repo.save(currentItem);

          HapticFeedback.vibrate();
          logoState = LoopHoleState.success;
          downloadProgress = 1.0;
          notifyListeners();

          // Keep checkmark visible for at least 2 seconds
          await Future.delayed(const Duration(seconds: 2));

          // Wait for any active full-screen ad to dismiss
          while (_adService.isFullScreenAdShowing) {
            await Future.delayed(const Duration(milliseconds: 200));
          }

          // Brief pause after ad close before clearing the checkmark
          await Future.delayed(const Duration(milliseconds: 1500));

          logoState = LoopHoleState.idle;
          showPlatformBadge = false;
          detectedPlatform = '';
          notifyListeners();
        } catch (e) {
          _setError(e.toString(), onError);
          if (currentItem != null) {
            await _repo.updateStatus(currentItem.id, DownloadItem.failed);
          }
        } finally {
          _isProcessing = false;
        }
      }

      startDownloadFlow();
      if (!isPremium) {
        showAdDuringDownload();
      }

    } catch (e) {
      _setError(e.toString(), onError);
      _isProcessing = false;
    }
  }

  void showAdDuringDownload() {
    if (logoState == LoopHoleState.downloading) {
      _adService.showInterstitialAd();
    }
  }
  
  void _setError(String message, Function(String)? onError) {
    // Map technical errors and raw exceptions into user-friendly copy
    String userFriendlyMsg = 'Download failed. Please check the link and try again.';
    final msgLower = message.toLowerCase();

    if (message == 'PHOTOS_NOT_SUPPORTED') {
      userFriendlyMsg = 'Photos & carousels are not supported. Video downloads only.';
    } else if (msgLower.contains('pinterest link appears to be an image') ||
               msgLower.contains('pinterest link is an image') ||
               msgLower.contains('download photos directly in pinterest')) {
      userFriendlyMsg = "This Pinterest link is an image. You can download photos directly in Pinterest (Tap the 3 dots -> 'Download image').";
    } else if (msgLower.contains('board or collection')) {
      userFriendlyMsg = "This link is for a Pinterest Board or Collection. Please copy the link to a single video Pin instead!";
    } else if (msgLower.contains('exception:') || msgLower.contains('dioexception')) {
      if (msgLower.contains('403') ||
          msgLower.contains('401') ||
          msgLower.contains('private')) {
        userFriendlyMsg = 'Private account media is not supported. Please use a public link.';
      } else if (msgLower.contains('timeout') ||
          msgLower.contains('timed out')) {
        userFriendlyMsg = 'Extraction timed out. Try again.';
      } else if (msgLower.contains('connection') ||
          msgLower.contains('socket') ||
          msgLower.contains('host')) {
        userFriendlyMsg = 'Server connection failed';
      } else if (msgLower.contains('could not extract media') ||
          msgLower.contains('no photo url') ||
          msgLower.contains('no download url') ||
          msgLower.contains('no formats')) {
        userFriendlyMsg = 'Could not extract media – please try again';
      } else if (msgLower.contains('no video streams') ||
          msgLower.contains('no download url')) {
        userFriendlyMsg = 'Could not extract video stream';
      }
    } else if (msgLower.contains('invalid link') ||
        msgLower.contains('no valid link')) {
      userFriendlyMsg = 'No valid link detected';
    }

    errorMessage = userFriendlyMsg;
    HapticFeedback.vibrate().then((_) {
      Future.delayed(
          const Duration(milliseconds: 200), () => HapticFeedback.vibrate());
    });
    logoState = LoopHoleState.error;
    notifyListeners();
    if (onError != null) onError(userFriendlyMsg);
    Future.delayed(const Duration(seconds: 2), () {
      logoState = LoopHoleState.idle;
      showPlatformBadge = false;
      detectedPlatform = '';
      errorMessage = '';
      notifyListeners();
    });
  }
}
