import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/responsive.dart';
import '../../main.dart';
import '../../data/services/remote_config_service.dart';
import 'dart:io';

class UpdateChecker {
  /// Checks for new versions on app startup using the Google Play In-App Updates API.
  /// Shows a prominent, beautiful dark-themed update dialog.
  static Future<void> checkForUpdate(GlobalKey<ScaffoldMessengerState> messengerKey) async {
    // In-app updates are only supported on Android.
    if (!Platform.isAndroid) return;

    debugPrint("UpdateChecker: Checking for updates...");

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      debugPrint("UpdateChecker: Device version: ${packageInfo.version}+${packageInfo.buildNumber}");
      
      final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final int minRequiredBuild = RemoteConfigService().minRequiredBuildNumber;
      final bool isHardForceUpdate = currentBuild < minRequiredBuild;

      final info = await InAppUpdate.checkForUpdate();
      
      final playStoreVersion = _getVersionNameFromCode(info.availableVersionCode);
      debugPrint("UpdateChecker: Play Store version: $playStoreVersion");

      final bool hasStoreUpdate = info.updateAvailability == UpdateAvailability.updateAvailable;

      if (isHardForceUpdate || hasStoreUpdate) {
        debugPrint("UpdateChecker: Update available (Hard Force: $isHardForceUpdate)");
        
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          _showUpdateDialog(context, isHardForce: isHardForceUpdate);
        } else {
          // Fallback to SnackBar if context is not available yet
          _showUpdateSnackBar(messengerKey);
        }
      } else {
        debugPrint("UpdateChecker: No update available");
      }
    } catch (e) {
      debugPrint("UpdateChecker: Error checking updates: $e");
    }
  }

  static String _getVersionNameFromCode(int? code) {
    if (code == null) return "Unknown (null)";
    switch (code) {
      case 20: return "1.0.9";
      case 19: return "1.0.8";
      case 18: return "1.0.8";
      case 17: return "1.0.7";
      case 16: return "1.0.7";
      case 15: return "1.0.7";
      case 14: return "1.0.6";
      case 13: return "1.0.6";
      case 12: return "1.0.6";
      case 11: return "1.0.5";
      case 10: return "1.0.5";
      case 9: return "1.0.4";
      case 8: return "1.0.4";
      case 7: return "1.0.3";
      case 6: return "1.0.2";
      case 5: return "1.0.1";
      default: return "1.0.0 (code: $code)";
    }
  }

  /// Displays the prominent modern dark-themed modal dialog.
  static void _showUpdateDialog(BuildContext context, {bool isHardForce = false}) {
    showDialog(
      context: context,
      barrierDismissible: !isHardForce,
      builder: (BuildContext context) {
        return PopScope(
          canPop: !isHardForce,
          child: Dialog(
            backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: context.rSize(24)),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(context.rSize(20)),
              border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonPurple.withValues(alpha: 0.15),
                  blurRadius: context.rSize(20),
                  spreadRadius: context.rSize(5),
                ),
              ],
            ),
            padding: EdgeInsets.all(context.rSize(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      color: AppColors.neonPurple,
                      size: context.rSize(28),
                    ),
                    SizedBox(width: context.rSize(12)),
                    Expanded(
                      child: Text(
                        'UPDATE AVAILABLE',
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: context.rFont(16),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.rSize(16)),
                Text(
                  isHardForce 
                      ? RemoteConfigService().forceUpdateMessage
                      : 'A new version of LoopHole is available with critical performance fixes, full device responsiveness, and status saver improvements.',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: context.rFont(13),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: context.rSize(24)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isHardForce)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'LATER',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: context.rFont(13),
                          ),
                        ),
                      ),
                    if (!isHardForce) SizedBox(width: context.rSize(12)),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleInstall();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonPurple,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.rSize(20),
                          vertical: context.rSize(12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rSize(10)),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'UPDATE NOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: context.rFont(13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  /// Displays the fallback non-intrusive soft notification Snackbar.
  static void _showUpdateSnackBar(GlobalKey<ScaffoldMessengerState> messengerKey) {
    final state = messengerKey.currentState;
    if (state == null) return;

    debugPrint("UpdateChecker: Showing update snackbar...");

    state.clearSnackBars();

    final snackBar = SnackBar(
      content: const Text(
        'Update available - tap to install',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      duration: const Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      action: SnackBarAction(
        label: 'Install',
        textColor: Colors.blueAccent,
        onPressed: () => _handleInstall(),
      ),
    );

    state.showSnackBar(snackBar);
  }

  /// Initiates the flexible update installation or falls back to Play Store app.
  static Future<void> _handleInstall() async {
    try {
      // 1. Try native flexible in-app update first
      await InAppUpdate.startFlexibleUpdate();
      
      // Complete update when downloaded
      InAppUpdate.completeFlexibleUpdate().then((_) {
        // App will restart automatically to install
      }).catchError((e) {
        debugPrint("UpdateChecker.completeFlexibleUpdate error: $e");
      });
    } catch (e) {
      debugPrint("Flexible update failed, falling back to Play Store URL: $e");
      // 2. Fallback: Launch Play Store details page
      await _launchPlayStore();
    }
  }

  /// Launches the Play Store app or opens the Store website in browser.
  static Future<void> _launchPlayStore() async {
    const packageName = "com.loophole.app";
    final playStoreUri = Uri.parse("market://details?id=$packageName");
    final webPlayStoreUri = Uri.parse("https://play.google.com/store/apps/details?id=$packageName");

    try {
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webPlayStoreUri)) {
        await launchUrl(webPlayStoreUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("UpdateChecker: Could not launch Play Store URLs");
      }
    } catch (e) {
      debugPrint("UpdateChecker._launchPlayStore error: $e");
    }
  }
}
