import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// RemoteConfigService — controls everything remotely from Firebase Console.
///
/// Keys you can change live from Firebase Console:
///   - maintenance_mode       → true/false  (shows full-screen maintenance screen)
///   - maintenance_title      → String      (title of maintenance message)
///   - maintenance_message    → String      (body text of maintenance message)
///   - app_banner_message     → String      (info banner on home screen, empty = hidden)
///   - app_banner_type        → 'info' / 'warning' / 'error'
///   - backend_url            → String      (your Render backend URL)
///   - force_update           → true/false  (forces user to update app)
///   - force_update_message   → String      (message shown on force update screen)
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig? _remoteConfig;

  // ── Default values (what app uses if Firebase is unreachable) ─────────────
  static const Map<String, dynamic> _defaults = {
    'maintenance_mode': false,
    'maintenance_title': 'Down for Maintenance',
    'maintenance_message':
        'We are working hard to improve your experience. Please check back in a few minutes. Sorry for the inconvenience! 🙏',
    'app_banner_message': '',
    'app_banner_type': 'info',
    'backend_url': 'https://vidgetgo-backend.onrender.com',
    'force_update': false,
    'force_update_message':
        'A new version is required to continue. Please update LoopHole from the Play Store.',
    'backup_url': 'https://vidgetgo-backend-3fj0.onrender.com',
  };

  Future<void> initialize() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        // In production: fetch fresh config every 1 hour
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Set defaults so app works even if offline
      await _remoteConfig!.setDefaults(_defaults);

      // Fetch and activate — non-blocking, won't crash if fails
      try {
        await _remoteConfig!.fetchAndActivate();
      } catch (e) {
        debugPrint('Remote Config fetch failed: $e');
      }

      // Listen for real-time updates (e.g., you turn on maintenance mode
      // mid-session and users get it without restarting app)
      _remoteConfig!.onConfigUpdated.listen((event) async {
        await _remoteConfig!.activate();
        debugPrint('RemoteConfig updated: ${event.updatedKeys}');
      });
    } catch (e) {
      debugPrint('RemoteConfig init failed (non-fatal): $e');
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  /// Is the app in maintenance mode? Shows full-screen overlay.
  bool get maintenanceMode =>
      _remoteConfig?.getBool('maintenance_mode') ?? false;

  /// Title shown on maintenance screen.
  String get maintenanceTitle =>
      _remoteConfig?.getString('maintenance_title') ??
      _defaults['maintenance_title'] as String;

  /// Body message shown on maintenance screen.
  String get maintenanceMessage =>
      _remoteConfig?.getString('maintenance_message') ??
      _defaults['maintenance_message'] as String;

  /// Banner message on home screen. Empty string = no banner shown.
  String get appBannerMessage =>
      _remoteConfig?.getString('app_banner_message') ?? '';

  /// Type of banner: 'info', 'warning', or 'error'
  String get appBannerType =>
      _remoteConfig?.getString('app_banner_type') ?? 'info';

  /// Live backend URL — change this to switch servers without an app update.
  String get backendUrl =>
      _remoteConfig?.getString('backend_url') ??
      _defaults['backend_url'] as String;

  /// Should app force user to update?
  bool get forceUpdate =>
      _remoteConfig?.getBool('force_update') ?? false;

  /// Message shown on force update screen.
  String get forceUpdateMessage =>
      _remoteConfig?.getString('force_update_message') ??
      _defaults['force_update_message'] as String;

  /// Backup backend URL if primary fails.
  String get backupUrl =>
      _remoteConfig?.getString('backup_url') ??
      _defaults['backup_url'] as String;
}
