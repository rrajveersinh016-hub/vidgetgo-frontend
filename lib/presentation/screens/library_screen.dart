import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/download_item.dart';
import '../../data/repositories/download_repository.dart';
import '../widgets/loophole_button.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final DownloadRepository _repo = DownloadRepository();
  List<DownloadItem> _downloads = [];
  bool _dontAskAgain = false;
  late TabController _tabController;

  // Audio Player State variables
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<DownloadItem?> _currentPlayingNotifier = ValueNotifier<DownloadItem?>(null);

  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _completeSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDownloads();

    // Setup Audio Player listeners
    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      _positionNotifier.value = p;
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((d) {
      _durationNotifier.value = d;
    });
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _playNext();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    _audioPlayer.dispose();
    _currentPlayingNotifier.dispose();
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadDownloads() async {
    final items = await _repo.getAll();
    if (mounted) {
      setState(() {
        _downloads = items;
      });
    }
  }

  Future<void> _deleteItem(DownloadItem item) async {
    // If the currently playing audio is deleted, stop player and clear it
    if (_currentPlayingNotifier.value?.id == item.id) {
      try {
        await _audioPlayer.stop();
      } catch (e) {
        _handleAudioError(e);
      }
      _currentPlayingNotifier.value = null;
    }
    await _repo.delete(item.id);
    _loadDownloads();
  }

  void _confirmDelete(BuildContext context, DownloadItem item) {
    _dontAskAgain = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D0D0D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: AppColors.neonPurple, 
              width: 1
            ),
          ),
          title: Text(
            _isPhoto(item.filePath)
                ? 'Delete Photo?'
                : _isAudio(item.filePath)
                    ? 'Delete Audio?'
                    : 'Delete Video?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This will permanently delete the downloaded file.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _dontAskAgain,
                    onChanged: (val) {
                      setDialogState(() {
                        _dontAskAgain = val ?? false;
                      });
                      setState(() {});
                    },
                    activeColor: AppColors.neonPurple,
                  ),
                  const Text(
                    "Don't ask again",
                    style: TextStyle(
                      color: Colors.grey, 
                      fontSize: 12
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('dontAskDelete', _dontAskAgain);
                await _deleteItem(item);
              },
              child: const Text(
                'DELETE',
                style: TextStyle(color: Color(0xFFFF3B3B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlatformDisplayName(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube': return 'Video';
      case 'instagram': return 'Reel';
      case 'facebook': return 'Social';
      case 'pinterest': return 'Pin';
      case 'whatsapp': return 'Status';
      default: return 'Custom';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1048576) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1073741824) return "${(bytes / 1048576).toStringAsFixed(1)} MB";
    return "${(bytes / 1073741824).toStringAsFixed(1)} GB";
  }

  bool _isPhoto(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  bool _isAudio(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp3') || lower.endsWith('.m4a');
  }

  bool _isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4');
  }

  void _handleAudioError(Object error) {
    debugPrint('AudioPlayer error: $error');
    if (error is PlatformException && error.code == 'AndroidAudioError') {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Audio playback is not supported on this device'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $error'),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _playAudio(DownloadItem item) async {
    try {
      final file = File(item.filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Audio file does not exist!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      
      _positionNotifier.value = Duration.zero;
      _durationNotifier.value = Duration.zero;
      _currentPlayingNotifier.value = item;
      
      await _audioPlayer.play(DeviceFileSource(item.filePath));
    } catch (e) {
      _handleAudioError(e);
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else if (_playerState == PlayerState.paused) {
        await _audioPlayer.resume();
      } else if (_currentPlayingNotifier.value != null) {
        await _playAudio(_currentPlayingNotifier.value!);
      }
    } catch (e) {
      _handleAudioError(e);
    }
  }

  void _playNext() {
    final audioItems = _downloads.where((item) => _isAudio(item.filePath)).toList();
    if (audioItems.isEmpty || _currentPlayingNotifier.value == null) return;
    
    final currentIndex = audioItems.indexWhere((item) => item.id == _currentPlayingNotifier.value!.id);
    if (currentIndex != -1 && currentIndex < audioItems.length - 1) {
      _playAudio(audioItems[currentIndex + 1]);
    } else if (audioItems.isNotEmpty) {
      _playAudio(audioItems.first);
    }
  }

  void _playPrevious() {
    final audioItems = _downloads.where((item) => _isAudio(item.filePath)).toList();
    if (audioItems.isEmpty || _currentPlayingNotifier.value == null) return;
    
    final currentIndex = audioItems.indexWhere((item) => item.id == _currentPlayingNotifier.value!.id);
    if (currentIndex > 0) {
      _playAudio(audioItems[currentIndex - 1]);
    } else if (audioItems.isNotEmpty) {
      _playAudio(audioItems.last);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildMiniPlayer() {
    final isPlaying = _playerState == PlayerState.playing;

    return ValueListenableBuilder<DownloadItem?>(
      valueListenable: _currentPlayingNotifier,
      builder: (context, currentItem, child) {
        if (currentItem == null) return const SizedBox.shrink();
        final title = currentItem.title;

        return ClipRRect(
          borderRadius: BorderRadius.circular(context.rSize(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: context.rSize(16), vertical: context.rSize(10)),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(context.rSize(16)),
                border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.35), width: context.rSize(1.5)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonPurple.withValues(alpha: 0.15),
                    blurRadius: context.rSize(12),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showExpandedPlayer,
                    child: Container(
                      width: context.rSize(40),
                      height: context.rSize(40),
                      decoration: BoxDecoration(
                        color: AppColors.neonPurple.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.music_note_rounded, color: AppColors.neonPurple, size: context.rSize(20)),
                    ),
                  ),
                  SizedBox(width: context.rSize(12)),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showExpandedPlayer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: context.rFont(13),
                            ),
                          ),
                          SizedBox(height: context.rSize(2)),
                          Text(
                            'Tap to view player',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: context.rFont(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: context.rSize(26),
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  IconButton(
                    icon: Icon(Icons.keyboard_arrow_up_rounded, color: Colors.grey, size: context.rSize(24)),
                    onPressed: _showExpandedPlayer,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showExpandedPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _buildExpandedPlayerSheet(context);
      },
    );
  }

  Widget _buildExpandedPlayerSheet(BuildContext context) {
    return Container(
      height: context.rHeight(0.85),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(context.rSize(32)),
          topRight: Radius.circular(context.rSize(32)),
        ),
        border: Border(
          top: BorderSide(color: AppColors.neonPurple, width: context.rSize(1.5)),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: context.rSize(24), vertical: context.rSize(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: context.rSize(40),
              height: context.rSize(4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(context.rSize(2)),
              ),
            ),
          ),
          SizedBox(height: context.rSize(16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: context.rSize(28)),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                'NOW PLAYING',
                style: GoogleFonts.orbitron(
                  color: AppColors.neonPurple,
                  fontSize: context.rFont(13),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(width: context.rSize(48)),
            ],
          ),
          const Spacer(),
          Center(
            child: StreamBuilder<PlayerState>(
              stream: _audioPlayer.onPlayerStateChanged,
              builder: (context, snapshot) {
                final state = snapshot.data ?? _playerState;
                return _RotatingVinylDisc(isPlaying: state == PlayerState.playing);
              },
            ),
          ),
          const Spacer(),
          ValueListenableBuilder<DownloadItem?>(
            valueListenable: _currentPlayingNotifier,
            builder: (context, currentItem, child) {
              return Text(
                currentItem?.title ?? 'Unknown',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: context.rFont(18),
                ),
              );
            },
          ),
          SizedBox(height: context.rSize(6)),
          Text(
            'LoopHole Downloaded Track',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: context.rFont(12),
            ),
          ),
          SizedBox(height: context.rSize(24)),
          ValueListenableBuilder<Duration>(
            valueListenable: _positionNotifier,
            builder: (context, position, child) {
              return ValueListenableBuilder<Duration>(
                valueListenable: _durationNotifier,
                builder: (context, duration, child) {
                  double value = 0.0;
                  if (duration.inMilliseconds > 0) {
                    value = position.inMilliseconds / duration.inMilliseconds;
                    value = value.clamp(0.0, 1.0);
                  }
                  
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.neonPurple,
                          inactiveTrackColor: Colors.white10,
                          thumbColor: Colors.white,
                          trackHeight: context.rSize(4),
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: context.rSize(6)),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: context.rSize(14)),
                        ),
                        child: Slider(
                          value: value,
                          onChanged: (val) async {
                            try {
                              final targetMs = (val * duration.inMilliseconds).toInt();
                              await _audioPlayer.seek(Duration(milliseconds: targetMs));
                            } catch (e) {
                              _handleAudioError(e);
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: context.rSize(24)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(color: Colors.grey, fontSize: context.rFont(11)),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(color: Colors.grey, fontSize: context.rFont(11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          SizedBox(height: context.rSize(24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: context.rSize(36)),
                onPressed: _playPrevious,
              ),
              SizedBox(width: context.rSize(24)),
              StreamBuilder<PlayerState>(
                stream: _audioPlayer.onPlayerStateChanged,
                builder: (context, snapshot) {
                  final state = snapshot.data ?? _playerState;
                  final isPlaying = state == PlayerState.playing;
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neonPurple,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonPurple.withValues(alpha: 0.4),
                          blurRadius: context.rSize(20),
                          spreadRadius: context.rSize(2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(context.rSize(4)),
                    child: IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: context.rSize(38),
                      ),
                      onPressed: _togglePlayPause,
                    ),
                  );
                },
              ),
              SizedBox(width: context.rSize(24)),
              IconButton(
                icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: context.rSize(36)),
                onPressed: _playNext,
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildList(List<DownloadItem> items, String emptyMessage) {
    if (items.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: context.rHeight(0.15)),
          Center(
            child: LoopHoleButton(
              state: LoopHoleState.idle,
              size: context.rWidth(0.5),
            ),
          ),
          SizedBox(height: context.rSize(30)),
          Center(
            child: Text(
              emptyMessage,
              style: GoogleFonts.orbitron(
                color: const Color(0xFF888888),
                fontSize: context.rFont(14),
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ),
        ],
      );
    }

    return ValueListenableBuilder<DownloadItem?>(
      valueListenable: _currentPlayingNotifier,
      builder: (context, currentItem, child) {
        return ListView.builder(
          padding: EdgeInsets.only(
            left: context.rSize(20),
            right: context.rSize(20),
            top: context.rSize(10),
            bottom: currentItem != null ? context.rSize(100) : context.rSize(10),
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isAudioFile = _isAudio(item.filePath);

            return GestureDetector(
              onTap: () async {
                if (isAudioFile) {
                  _playAudio(item);
                } else {
                  try {
                    const channel = MethodChannel('com.loophole.app/media');
                    await channel.invokeMethod('openVideo', {'path': item.filePath});
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Cannot open file: $e')),
                      );
                    }
                  }
                }
              },
              child: Container(
                margin: EdgeInsets.only(bottom: context.rSize(12)),
                padding: EdgeInsets.all(context.rSize(16)),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(context.rSize(16)),
                  border: Border.all(
                    color: AppColors.neonPurple.withValues(alpha: 0.15),
                    width: context.rSize(1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPurple.withValues(alpha: 0.05),
                      blurRadius: context.rSize(8),
                      offset: Offset(0, context.rSize(2)),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.rSize(40),
                      height: context.rSize(40),
                      decoration: BoxDecoration(
                        color: AppColors.neonPurple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPhoto(item.filePath)
                            ? Icons.image_rounded
                            : isAudioFile
                                ? Icons.music_note_rounded
                                : Icons.play_arrow_rounded,
                        color: AppColors.neonPurple,
                        size: context.rSize(20),
                      ),
                    ),
                    SizedBox(width: context.rSize(16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: context.rFont(14),
                            ),
                          ),
                          SizedBox(height: context.rSize(4)),
                          Row(
                            children: [
                              Container(
                                width: context.rSize(6),
                                height: context.rSize(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.neonPurple,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: context.rSize(6)),
                              Text(
                                _getPlatformDisplayName(item.platform),
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: context.rFont(11),
                                ),
                              ),
                              SizedBox(width: context.rSize(12)),
                              Text(
                                _formatBytes(item.fileSize),
                                style: TextStyle(
                                  color: AppColors.neonPurple,
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.rFont(11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.grey, size: context.rSize(20)),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final dontAsk = prefs.getBool('dontAskDelete') ?? false;
                        if (dontAsk) {
                          _deleteItem(item);
                        } else {
                          if (context.mounted) {
                            _confirmDelete(context, item);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final videoItems = _downloads.where((item) => _isVideo(item.filePath)).toList();
    final audioItems = _downloads.where((item) => _isAudio(item.filePath)).toList();
    final photoItems = _downloads.where((item) => _isPhoto(item.filePath)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'LIBRARY',
          style: GoogleFonts.orbitron(
            color: AppColors.neonPurple,
            fontSize: context.rFont(20),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (_downloads.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.grey),
              onPressed: () async {
                await _repo.clearAll();
                try {
                  await _audioPlayer.stop();
                } catch (e) {
                  _handleAudioError(e);
                }
                _currentPlayingNotifier.value = null;
                _loadDownloads();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.neonPurple,
          labelColor: AppColors.neonPurple,
          unselectedLabelColor: Colors.grey,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: context.rFont(14)),
          unselectedLabelStyle: TextStyle(fontSize: context.rFont(14)),
          tabs: const [
            Tab(text: 'VIDEOS'),
            Tab(text: 'AUDIO'),
            Tab(text: 'PHOTOS'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              RefreshIndicator(
                color: AppColors.neonPurple,
                backgroundColor: const Color(0xFF0D0D0D),
                onRefresh: _loadDownloads,
                child: _buildList(videoItems, 'NO VIDEOS YET'),
              ),
              RefreshIndicator(
                color: AppColors.neonPurple,
                backgroundColor: const Color(0xFF0D0D0D),
                onRefresh: _loadDownloads,
                child: _buildList(audioItems, 'NO AUDIO YET'),
              ),
              RefreshIndicator(
                color: AppColors.neonPurple,
                backgroundColor: const Color(0xFF0D0D0D),
                onRefresh: _loadDownloads,
                child: _buildList(photoItems, 'NO PHOTOS YET'),
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildMiniPlayer(),
          ),
        ],
      ),
    );
  }
}

class _RotatingVinylDisc extends StatefulWidget {
  final bool isPlaying;
  const _RotatingVinylDisc({required this.isPlaying});

  @override
  State<_RotatingVinylDisc> createState() => _RotatingVinylDiscState();
}

class _RotatingVinylDiscState extends State<_RotatingVinylDisc> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _RotatingVinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double recordSize = context.rWidth(0.65);
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * 3.14159265,
          child: Container(
            width: recordSize,
            height: recordSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF101010),
                  Color(0xFF070707),
                  Color(0xFF1A1A1A),
                  Color(0xFF020202),
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonPurple.withValues(alpha: 0.15),
                  blurRadius: context.rSize(40),
                  spreadRadius: context.rSize(5),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: recordSize * 0.3,
                height: recordSize * 0.3,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonPurple,
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: recordSize * 0.13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
