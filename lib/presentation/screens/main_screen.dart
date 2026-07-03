import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/colors.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/remote_config_service.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'status_saver_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _statusSaverAdShownThisSession = false;

  final List<Widget> _pages = [
    const HomeScreen(),
    const StatusSaverScreen(),
    const LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final config = RemoteConfigService();
    final bool isMaintenanceMode = config.maintenanceMode;
    final String bannerMessage = config.appBannerMessage;
    final String bannerType = config.appBannerType;

    // ── Full-screen Maintenance Overlay ─────────────────────────────────────
    // When you set maintenance_mode = true in Firebase Console, ALL users
    // instantly see this screen instead of the app. No update needed.
    if (isMaintenanceMode) {
      return _MaintenanceScreen(
        title: config.maintenanceTitle,
        message: config.maintenanceMessage,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Info/Warning Banner ────────────────────────────────────────────
          // Set app_banner_message in Firebase Console to show a banner.
          // Set it to empty string "" to hide it.
          if (bannerMessage.isNotEmpty)
            _AppBanner(message: bannerMessage, type: bannerType),

          Expanded(child: _pages[_currentIndex]),
          SafeArea(
            top: false,
            child: AdService().buildBannerAd(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1 && !_statusSaverAdShownThisSession) {
            _statusSaverAdShownThisSession = true;
            AdService().showInterstitialAd();
          }
        },
        backgroundColor: Colors.black,
        selectedItemColor: AppColors.neonPurple,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.downloading_rounded),
            label: 'Downloader',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            label: 'Status Saver',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_copy_rounded),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

// ── Maintenance Screen ───────────────────────────────────────────────────────
// Shown when maintenance_mode = true in Firebase Remote Config.
// Users cannot use the app until you set it back to false.
class _MaintenanceScreen extends StatelessWidget {
  final String title;
  final String message;

  const _MaintenanceScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.build_circle_outlined,
                    color: Colors.orange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.orbitron(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'We\'ll be back shortly! 🙏',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── App Banner ───────────────────────────────────────────────────────────────
// Shown at top of app when app_banner_message is set in Firebase.
// Types: 'info' (blue), 'warning' (orange), 'error' (red)
class _AppBanner extends StatefulWidget {
  final String message;
  final String type;

  const _AppBanner({required this.message, required this.type});

  @override
  State<_AppBanner> createState() => _AppBannerState();
}

class _AppBannerState extends State<_AppBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final Color bannerColor = switch (widget.type) {
      'error' => const Color(0xFFCC2200),
      'warning' => const Color(0xFFCC7700),
      _ => const Color(0xFF1565C0), // info = blue
    };

    final IconData bannerIcon = switch (widget.type) {
      'error' => Icons.error_outline_rounded,
      'warning' => Icons.warning_amber_rounded,
      _ => Icons.info_outline_rounded,
    };

    return Container(
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(bannerIcon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
