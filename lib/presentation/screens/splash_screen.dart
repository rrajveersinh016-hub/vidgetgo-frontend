import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/services/app_open_ad_manager.dart';
import 'main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timeoutTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    
    AppOpenAdManager().isSplashActive = true;
    AppOpenAdManager().onSplashAdDismissed = _navigateToHome;

    // Start 3-second timeout timer. If ad takes longer than 3 seconds to load/show, 
    // we bypass it and navigate directly to home screen, saving it for warm start.
    _timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && AppOpenAdManager().isSplashActive) {
        AppOpenAdManager().isSplashActive = false;
        _navigateToHome();
      }
    });

    // If the ad was already somehow preloaded, show it immediately.
    if (AppOpenAdManager().isAdAvailable) {
      AppOpenAdManager().showAdIfAvailable();
    }
  }

  void _navigateToHome() {
    if (_navigated) return;
    _navigated = true;
    _timeoutTimer?.cancel();
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    AppOpenAdManager().onSplashAdDismissed = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'LoopHole',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
