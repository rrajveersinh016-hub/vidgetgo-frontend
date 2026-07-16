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

    // Start 5-second timeout timer. If ad takes longer than 5 seconds to load/show, 
    // we bypass it and navigate directly to home screen, saving it for warm start.
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
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
      body: Stack(
        children: [
          Center(
            child: Text(
              'LoopHole',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const Positioned(
            bottom: 24,
            left: 32,
            right: 32,
            child: SafeArea(
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                minHeight: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
