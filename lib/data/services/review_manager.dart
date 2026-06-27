import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewManager {
  static const String _keyDownloadCount = 'download_count';
  static const String _keyLastPromptTime = 'last_review_prompt_time';

  /// Increments the download count by 1 in SharedPreferences and returns the new count.
  static Future<int> incrementDownloadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_keyDownloadCount) ?? 0;
      final newCount = currentCount + 1;
      await prefs.setInt(_keyDownloadCount, newCount);
      debugPrint("ReviewManager: Download count incremented to $newCount");
      return newCount;
    } catch (e) {
      debugPrint("ReviewManager.incrementDownloadCount error: $e");
      return 0;
    }
  }

  /// Triggers the native Google Play In-App Review dialog if eligibility conditions are met.
  static Future<void> showReviewIfEligible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadCount = prefs.getInt(_keyDownloadCount) ?? 0;
      final lastPromptMillis = prefs.getInt(_keyLastPromptTime) ?? 0;

      // Condition 1: Check if the download count is a multiple of 5
      final isEveryFifthDownload = downloadCount > 0 && downloadCount % 5 == 0;

      // Condition 2: Check if at least 7 days have passed since the last prompt
      final lastPromptTime = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
      final daysSinceLastPrompt = DateTime.now().difference(lastPromptTime).inDays;
      final isMinDaysElapsed = lastPromptMillis == 0 || daysSinceLastPrompt >= 7;

      debugPrint("ReviewManager check: downloadCount=$downloadCount, isEveryFifth=$isEveryFifthDownload, daysSinceLastPrompt=$daysSinceLastPrompt, isMinDaysElapsed=$isMinDaysElapsed");

      if (isEveryFifthDownload && isMinDaysElapsed) {
        final InAppReview inAppReview = InAppReview.instance;
        
        // Check if the In-App Review API is available on this platform/device
        final isAvailable = await inAppReview.isAvailable();
        if (isAvailable) {
          debugPrint("ReviewManager: Requesting native in-app review...");
          await inAppReview.requestReview();
          
          // Save the current timestamp to track the last show time
          await prefs.setInt(_keyLastPromptTime, DateTime.now().millisecondsSinceEpoch);
        } else {
          debugPrint("ReviewManager: In-App Review API is not available");
        }
      }
    } catch (e) {
      // Catch all exceptions silently (log only)
      debugPrint("ReviewManager.showReviewIfEligible error: $e");
    }
  }
}
