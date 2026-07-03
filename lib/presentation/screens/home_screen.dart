import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/responsive.dart';
import '../viewmodels/home_viewmodel.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/loophole_button.dart';
import 'premium_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  StreamSubscription? _intentDataStreamSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // We use post frame callback to guarantee MultiProvider context is valid before triggering downloads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      _initSharingIntents();

      try {
        final List<SharedMediaFile> value = await ReceiveSharingIntent.instance.getInitialMedia();
        if (value.isNotEmpty) {
          _processSharedMediaList(value);
          await ReceiveSharingIntent.instance.reset();
        } else {
          if (mounted) {
            final viewModel = Provider.of<HomeViewModel>(context, listen: false);
            viewModel.showAppStartAd();
          }
        }
      } catch (e) {
        if (mounted) {
          final viewModel = Provider.of<HomeViewModel>(context, listen: false);
          viewModel.showAppStartAd();
        }
      }
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      try {
        await Permission.storage.request();
      } catch (e) {
        debugPrint('Permission request failed: $e');
      }
    }
  }

  void _initSharingIntents() {
    // Handle sharing events while the app is in background/foreground memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      _processSharedMediaList(value);
    }, onError: (err) {
      // debugPrint("Share Intent Stream Error: $err");
    });
  }

  void _processSharedMediaList(List<SharedMediaFile> mediaList) {
    for (final media in mediaList) {
      if (media.type == SharedMediaType.text || media.type == SharedMediaType.url) {
        _processIncomingText(media.path);
        break; // Only extract first occurrence
      }
    }
  }

  void _processIncomingText(String sharedText) {
    if (sharedText.isEmpty) return;

    // Safely isolate URL if the share context provided trailing message text
    final RegExp urlRegex = RegExp(r'(https?:\/\/[^\s]+)');
    final match = urlRegex.firstMatch(sharedText);
    final String finalUrl = match != null ? match.group(0) ?? sharedText : sharedText;

    if (mounted) {
      final viewModel = Provider.of<HomeViewModel>(context, listen: false);
      
      // Delay execution microsecond to avoid blocking rendering stack
      Future.microtask(() {
        if (!mounted) return;
        viewModel.onCircleTapped(
          context: context,
          manualUrl: finalUrl,
          onError: (msg) {
            if (mounted) {
              _showErrorSnackbar(msg);
            }
          },
        );
      });
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFFF3B3B), width: 1),
          ),
          duration: const Duration(seconds: 10), // Reduced from 5 minutes
          action: SnackBarAction(
            label: 'OK',
            textColor: const Color(0xFFFF3B3B),
            onPressed: () {
              try {
                ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final viewModel = context.watch<HomeViewModel>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpBottomSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.workspace_premium), 
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                onTap: () {
                  viewModel.onCircleTapped(
                    context: context,
                    onError: (msg) {
                      if (context.mounted) {
                        _showErrorSnackbar(msg);
                      }
                    },
                  );
                },
                child: LoopHoleButton(
                  state: viewModel.logoState,
                  progress: viewModel.downloadProgress,

                ),
              ),
            ),
            Center(
              child: Transform.translate(
                offset: Offset(0, context.rHeight(0.22)),
                child: Builder(
                  builder: (context) {
                    String logText = '— TAP TO DOWNLOAD FROM CLIPBOARD —';
                    
                    if (viewModel.logoState == LoopHoleState.downloading) {
                      logText = '— DOWNLOADING VIDEO —';
                    } else if (viewModel.logoState == LoopHoleState.success) {
                      logText = '— DOWNLOAD COMPLETE —';
                    } else if (viewModel.logoState == LoopHoleState.error) {
                      logText = '— CONNECTION FAILED —';
                    } else if (viewModel.detectedPlatform.isNotEmpty) {
                      logText = '— EXTRACTING VIDEO STREAM —';
                    }

                    final isStatus = viewModel.detectedPlatform.isNotEmpty || viewModel.logoState != LoopHoleState.idle;
                    final logColor = isStatus ? const Color(0xFF9D00FF) : const Color(0xFF555555);

                    return AnimatedSwitcher(
                      duration: 300.ms,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: context.rSize(16)),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            logText,
                            key: ValueKey(logText),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: GoogleFonts.dmSans(
                              color: logColor,
                              fontSize: context.rFont(12),
                              letterSpacing: isStatus ? context.rSize(3.0) : context.rSize(1.5),
                              fontWeight: isStatus ? FontWeight.w800 : FontWeight.w500,
                              shadows: isStatus ? [
                                BoxShadow(color: const Color(0xFF9D00FF).withValues(alpha: 0.4), blurRadius: context.rSize(12))
                              ] : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                ),
            ),
          ),
        ],
      ),
    ),
  );
}

  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(context.rSize(24)),
              topRight: Radius.circular(context.rSize(24)),
            ),
            border: const Border(
              top: BorderSide(color: AppColors.neonPurple, width: 1.5),
            ),
          ),
          padding: EdgeInsets.only(
            left: context.rSize(24),
            right: context.rSize(24),
            top: context.rSize(20),
            bottom: context.rSize(24) + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: context.rSize(40),
                  height: context.rSize(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(context.rSize(2)),
                  ),
                ),
              ),
              SizedBox(height: context.rSize(20)),
              Text(
                'USER GUIDE',
                textAlign: TextAlign.center,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: context.rFont(18),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: context.rSize(24)),
              _buildGuideStep(
                context,
                '1',
                'Copy a Link',
                'Find any video you want to save, tap Share and copy the video link.',
              ),
              SizedBox(height: context.rSize(16)),
              _buildGuideStep(
                context,
                '2',
                'Open LoopHole & Tap',
                'Open LoopHole and tap the portal circle. It automatically reads your copied link!',
              ),
              SizedBox(height: context.rSize(16)),
              _buildGuideStep(
                context,
                '3',
                'Share Directly (Easier!)',
                'Tap Share on any video and select LoopHole from the share menu. Download starts automatically!',
              ),
              SizedBox(height: context.rSize(16)),
              _buildGuideStep(
                context,
                '4',
                'Find Your Video',
                'All saved videos appear in your Downloads tab and phone gallery instantly.',
              ),
              SizedBox(height: context.rSize(32)),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    const channel = MethodChannel('com.loophole.app/media');
                    await channel.invokeMethod('launchEmail', {
                      'email': 'support.loophole@gmail.com',
                      'subject': 'LoopHole Support'
                    });
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open email client: $e')),
                      );
                    }
                  }
                },
                icon: Icon(Icons.mail_outline, color: Colors.white, size: context.rSize(20)),
                label: Text(
                  'CONTACT SUPPORT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: context.rFont(14),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPurple,
                  padding: EdgeInsets.symmetric(vertical: context.rSize(16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.rSize(12)),
                  ),
                  elevation: 8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideStep(BuildContext context, String stepNumber, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: context.rSize(28),
          height: context.rSize(28),
          decoration: BoxDecoration(
            color: AppColors.neonPurple.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neonPurple, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonPurple.withValues(alpha: 0.3),
                blurRadius: context.rSize(6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: context.rFont(14),
            ),
          ),
        ),
        SizedBox(width: context.rSize(16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: context.rFont(14),
                ),
              ),
              SizedBox(height: context.rSize(4)),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: context.rFont(12),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
