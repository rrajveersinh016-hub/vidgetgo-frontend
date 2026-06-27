import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/responsive.dart';
import '../viewmodels/home_viewmodel.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  void _showUnlockSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black, // Vantablack
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.rSize(24))),
      ),
      builder: (context) {
        return Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            return Container(
              padding: EdgeInsets.all(context.rSize(32)),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(context.rSize(24))),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: context.rSize(1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    size: context.rSize(60),
                    color: const Color(0xFF00FFFF),
                  ),
                  SizedBox(height: context.rSize(16)),
                  Text(
                    'Unlock Pro for 3 Days',
                    style: GoogleFonts.orbitron(
                      fontSize: context.rFont(22),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: context.rSize(16)),
                  Text(
                    'Watch 5 short video ads to unlock 3 days of Pro features (Zero Ads).',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: context.rFont(14),
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: context.rSize(30)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.rSize(24), vertical: context.rSize(12)),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(context.rSize(12)),
                      border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.3), width: context.rSize(1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill, color: AppColors.neonPurple, size: context.rSize(24)),
                            SizedBox(width: context.rSize(12)),
                            Text(
                              'Ads Watched: ${viewModel.adsWatchedCount}/5',
                              style: GoogleFonts.orbitron(
                                fontSize: context.rFont(16),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.rSize(6)),
                        Text(
                          '${5 - viewModel.adsWatchedCount} more to go',
                          style: GoogleFonts.dmSans(
                            fontSize: context.rFont(12),
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.rSize(30)),
                  SizedBox(
                    width: double.infinity,
                    height: context.rSize(56),
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        if (viewModel.isPremium) {
                          Navigator.pop(context); // Already pro
                          return;
                        }
                        
                        // Pass current BuildContext so watchRewardedAd can display SnackBars
                        await viewModel.watchRewardedAd(context);
                        
                        // If it hits 5, we show success snackbar and close screen
                        if (viewModel.isPremium && context.mounted) {
                          Navigator.pop(context); // close sheet
                          Navigator.pop(context); // close premium screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '✅ Pro Unlocked for 3 Days! Ads Removed.',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: Colors.green[800],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Colors.white24, width: 1),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonPurple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.rSize(16)),
                        ),
                      ),
                      child: Text(
                        'WATCH AD (${5 - viewModel.adsWatchedCount} REMAINING)',
                        style: GoogleFonts.orbitron(
                          fontSize: context.rFont(14),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.rSize(20)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();
    final isPremium = viewModel.isPremium;

    return Scaffold(
      backgroundColor: Colors.black, // Vantablack
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: context.rSize(24)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Core UI
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: context.rSize(30.0)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The glowing Crown Container
                    Container(
                      padding: EdgeInsets.all(context.rSize(30)),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0D0D0D),
                        border: Border.all(
                          color: isPremium ? const Color(0xFF00FFFF) : Colors.white.withValues(alpha: 0.1),
                          width: context.rSize(1.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isPremium ? const Color(0xFF00FFFF).withValues(alpha: 0.5) : const Color(0xFF00FFFF).withValues(alpha: 0.3),
                            blurRadius: context.rSize(40),
                            spreadRadius: context.rSize(2),
                          ),
                          BoxShadow(
                            color: AppColors.neonPurple.withValues(alpha: 0.2),
                            blurRadius: context.rSize(80),
                            spreadRadius: context.rSize(10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.workspace_premium,
                        size: context.rSize(80),
                        color: isPremium ? const Color(0xFF00FFFF) : Colors.white,
                      ),
                    ),
                    
                    SizedBox(height: context.rSize(40)),
                    
                    Text(
                      'LOOPHOLE PRO',
                      style: GoogleFonts.orbitron(
                        fontSize: context.rFont(28),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                        shadows: [
                          BoxShadow(
                            color: const Color(0xFF00FFFF),
                            blurRadius: context.rSize(20),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: context.rSize(12)),
                    
                    Text(
                      isPremium 
                        ? 'You are currently using LoopHole Pro. Enjoy an ad-free experience.'
                        : 'Watch 5 short video ads to unlock 3 days of Pro features (Zero Ads).',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: context.rFont(16),
                        color: Colors.grey[400],
                        letterSpacing: 0.5,
                      ),
                    ),
                    
                    if (isPremium && viewModel.proExpiryDate != null) ...[
                      SizedBox(height: context.rSize(30)),
                      PremiumCountdownWidget(expiryDate: viewModel.proExpiryDate!),
                    ],
                    
                    SizedBox(height: context.rSize(40)),
                    
                    // The Glow Upgrade Button
                    Container(
                      width: double.infinity,
                      height: context.rSize(56),
                      decoration: BoxDecoration(
                        boxShadow: isPremium ? null : [
                          BoxShadow(
                            color: AppColors.neonPurple.withValues(alpha: 0.4),
                            blurRadius: context.rSize(25),
                            offset: Offset(0, context.rSize(8)),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isPremium ? null : () {
                          HapticFeedback.heavyImpact();
                          _showUnlockSheet(context);
                        },
                        style: isPremium 
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: const Color(0xFF1E1E1E),
                              disabledForegroundColor: Colors.grey[600],
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.rSize(16)),
                                side: BorderSide(color: const Color(0xFF555555), width: context.rSize(1)),
                              ),
                            )
                          : ElevatedButton.styleFrom(
                              backgroundColor: AppColors.neonPurple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(context.rSize(16)),
                              ),
                            ),
                        child: isPremium
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified, color: const Color(0xFF00FFFF), size: context.rSize(20)),
                                SizedBox(width: context.rSize(10)),
                                Text(
                                  'PRO ACTIVE',
                                  style: GoogleFonts.orbitron(
                                    fontSize: context.rFont(16),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'UNLOCK PRO (FREE)',
                              style: GoogleFonts.orbitron(
                                fontSize: context.rFont(16),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumCountdownWidget extends StatefulWidget {
  final DateTime expiryDate;
  const PremiumCountdownWidget({super.key, required this.expiryDate});

  @override
  State<PremiumCountdownWidget> createState() => _PremiumCountdownWidgetState();
}

class _PremiumCountdownWidgetState extends State<PremiumCountdownWidget> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    setState(() {
      _timeLeft = widget.expiryDate.difference(DateTime.now());
      if (_timeLeft.isNegative || _timeLeft == Duration.zero) {
        _timeLeft = Duration.zero;
        _timer.cancel();
        // Refresh premium state in ViewModel
        Provider.of<HomeViewModel>(context, listen: false).loadPremiumState();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return "00d 00h 00m 00s";
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(days)}d ${twoDigits(hours)}h ${twoDigits(minutes)}m ${twoDigits(seconds)}s";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.rSize(24), vertical: context.rSize(16)),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(context.rSize(16)),
        border: Border.all(color: const Color(0xFF00FFFF).withValues(alpha: 0.3), width: context.rSize(1.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFFF).withValues(alpha: 0.1),
            blurRadius: context.rSize(15),
            spreadRadius: context.rSize(1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'TIME REMAINING',
            style: GoogleFonts.orbitron(
              color: Colors.grey[400],
              fontSize: context.rFont(12),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: context.rSize(8)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatDuration(_timeLeft),
              maxLines: 1,
              style: GoogleFonts.orbitron(
                color: const Color(0xFF00FFFF),
                fontSize: context.rFont(22),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

