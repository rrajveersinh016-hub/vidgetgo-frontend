import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/download_item.dart';
import '../../data/repositories/download_repository.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String path;
  const VideoThumbnailWidget({super.key, required this.path});

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  static const _channel = MethodChannel('com.loophole.app/media');
  Uint8List? _thumbnailBytes;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final Uint8List? bytes = await _channel.invokeMethod('getVideoThumbnail', {'path': widget.path});
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailBytes != null) {
      return Image.memory(
        _thumbnailBytes!,
        fit: BoxFit.cover,
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: AppColors.neonPurple, strokeWidth: 2),
        )
      ),
    );
  }
}

class StatusSaverScreen extends StatefulWidget {
  const StatusSaverScreen({super.key});

  @override
  State<StatusSaverScreen> createState() => _StatusSaverScreenState();
}

class _StatusSaverScreenState extends State<StatusSaverScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  bool _isSaverEnabled = false;
  List<File> _photoFiles = [];
  List<File> _videoFiles = [];
  Map<String, int> _cacheTimes = {};
  late TabController _tabController;
  final DownloadRepository _repo = DownloadRepository();
  bool _isLoading = false;
  final Set<String> _selectedFileNames = {};
  
  static const _mediaChannel = MethodChannel('com.loophole.app/media');
  bool _useSAF = false;
  String _safType = 'whatsapp';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted && _selectedFileNames.isNotEmpty) {
        setState(() {
          _selectedFileNames.clear();
        });
      }
    });
    _loadEnabledState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEnabledState() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('status_saver_enabled') ?? false;
    final safType = prefs.getString('status_saver_saf_type') ?? 'whatsapp';
    
    bool useSAF = false;
    try {
      useSAF = await _mediaChannel.invokeMethod<bool>('useSAF') ?? false;
    } catch (e) {
      // ignore
    }

    setState(() {
      _isSaverEnabled = enabled;
      _safType = safType;
      _useSAF = useSAF;
    });

    if (enabled) {
      _scanAndCacheStatuses();
    }
  }

  Future<void> _toggleSaver(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      if (_useSAF) {
        final hasPerm = await _mediaChannel.invokeMethod<bool>('hasFolderPermission', {'type': _safType}) ?? false;
        if (!hasPerm) {
          if (mounted) {
            final granted = await _showSAFGuideDialog();
            if (!granted) {
              await prefs.setBool('status_saver_enabled', false);
              setState(() {
                _isSaverEnabled = false;
              });
              return;
            }
          }
        }
      } else {
        final hasPermission = await _checkAndRequestPermission();
        if (!hasPermission) {
          await prefs.setBool('status_saver_enabled', false);
          setState(() {
            _isSaverEnabled = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission is required for Status Saver.'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
    }

    await prefs.setBool('status_saver_enabled', value);
    setState(() {
      _isSaverEnabled = value;
      _selectedFileNames.clear();
      if (!value) {
        _photoFiles = [];
        _videoFiles = [];
      }
    });

    if (value) {
      _scanAndCacheStatuses();
    }
  }

  Future<bool> _showSAFGuideDialog() async {
    String selectedType = _safType;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0D0D0D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rSize(20)),
                side: BorderSide(color: AppColors.neonPurple.withValues(alpha: 0.2), width: 1.5),
              ),
              title: Center(
                child: Text(
                  'SETUP STATUS SAVER',
                  style: GoogleFonts.orbitron(
                    color: AppColors.neonPurple,
                    fontSize: context.rFont(18),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose WhatsApp Format:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: context.rFont(14),
                      ),
                    ),
                    SizedBox(height: context.rSize(8)),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedType = 'whatsapp';
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: context.rSize(10)),
                              decoration: BoxDecoration(
                                color: selectedType == 'whatsapp' 
                                    ? AppColors.neonPurple.withValues(alpha: 0.15) 
                                    : Colors.black,
                                borderRadius: BorderRadius.circular(context.rSize(10)),
                                border: Border.all(
                                  color: selectedType == 'whatsapp' 
                                      ? AppColors.neonPurple 
                                      : Colors.white12,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Standard',
                                  style: TextStyle(
                                    color: selectedType == 'whatsapp' ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: context.rFont(13),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: context.rSize(10)),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedType = 'whatsapp_business';
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: context.rSize(10)),
                              decoration: BoxDecoration(
                                color: selectedType == 'whatsapp_business' 
                                    ? AppColors.neonPurple.withValues(alpha: 0.15) 
                                    : Colors.black,
                                borderRadius: BorderRadius.circular(context.rSize(10)),
                                border: Border.all(
                                  color: selectedType == 'whatsapp_business' 
                                      ? AppColors.neonPurple 
                                      : Colors.white12,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Business',
                                  style: TextStyle(
                                    color: selectedType == 'whatsapp_business' ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: context.rFont(13),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.rSize(24)),
                    Text(
                      'How to grant permission:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: context.rFont(14),
                      ),
                    ),
                    SizedBox(height: context.rSize(12)),
                    _buildGuideStep(
                      number: '1',
                      title: 'Tap "GRANT ACCESS"',
                      description: 'We will open the WhatsApp folder automatically.',
                    ),
                    _buildGuideStep(
                      number: '2',
                      title: 'Tap "USE THIS FOLDER"',
                      description: 'Tap the blue button at the bottom of the screen (do not select other folders).',
                    ),
                    _buildGuideStep(
                      number: '3',
                      title: 'Tap "ALLOW"',
                      description: 'Grant LoopHole access to sync your viewed statuses.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(context.rSize(10)),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: context.rSize(16), vertical: context.rSize(10)),
                  ),
                  onPressed: () async {
                    setState(() {
                      _safType = selectedType;
                    });
                    await prefs.setString('status_saver_saf_type', selectedType);
                    
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: Text(
                    'GRANT ACCESS',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: context.rFont(12),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        final granted = await _mediaChannel.invokeMethod<bool>('requestFolderPermission', {'type': _safType}) ?? false;
        return granted;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Widget _buildGuideStep({required String number, required String title, required String description}) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.rSize(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.rSize(24),
            height: context.rSize(24),
            decoration: const BoxDecoration(
              color: AppColors.neonPurple,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: context.rFont(12),
                ),
              ),
            ),
          ),
          SizedBox(width: context.rSize(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: context.rFont(13),
                  ),
                ),
                SizedBox(height: context.rSize(2)),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: context.rFont(11),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Future<bool> _checkAndRequestPermission() async {
    if (Platform.isAndroid) {
      try {
        // We can use device_info_plus, but I don't know if it's imported.
        // The user suggested using flutter's platform check or permission_handler handling.
        // Wait! The user says "Use flutter's Platform check and pass Android version via MethodChannel or use permission_handler's built-in handling"
        // Actually, Permission.photos and Permission.videos are available in permission_handler.
        // If we request Permission.storage, on Android 13 it will auto-fail if it's not declared in manifest.
        // Better:
        if (await Permission.photos.isRestricted) {
           // Not Android 13
        }
        
        if (await Permission.storage.isGranted) {
           return true;
        }
        
        // Let's just request photos, videos, and storage. permission_handler handles SDK levels internally.
        final statuses = await [
          Permission.storage,
          Permission.photos,
          Permission.videos,
        ].request();

        return statuses[Permission.storage]?.isGranted == true ||
               (statuses[Permission.photos]?.isGranted == true && statuses[Permission.videos]?.isGranted == true);
      } catch (e) {
        debugPrint('Permission request failed: $e');
        return false;
      }
    }
    return false;
  }

  Future<bool> _checkPermission() async {
    if (Platform.isAndroid) {
        return (await Permission.storage.isGranted) ||
               (await Permission.photos.isGranted && await Permission.videos.isGranted);
    }
    return false;
  }

  Future<void> _scanAndCacheStatuses() async {
    if (!mounted) return;
    try {
      if (!_isSaverEnabled) return;

      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      if (_useSAF) {
        final hasPerm = await _mediaChannel.invokeMethod<bool>('hasFolderPermission', {'type': _safType}) ?? false;
        if (!hasPerm) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        final success = await _mediaChannel.invokeMethod<bool>('syncStatuses', {'type': _safType}) ?? false;
        if (!success) {
          debugPrint("SAF Status Sync failed.");
        }
      } else {
        final hasPermission = await _checkPermission();
        if (!hasPermission) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }

        final List<Directory> whatsappDirs = [
          Directory('/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses'),
          Directory('/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses'),
          Directory('/storage/emulated/0/WhatsApp/Media/.Statuses'),
        ];

        final tempDir = await getTemporaryDirectory();
        final cacheDir = Directory('${tempDir.path}/StatusSaver');
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }

        final prefs = await SharedPreferences.getInstance();
        bool foundAnyDir = false;

        for (final dir in whatsappDirs) {
          if (await dir.exists()) {
            foundAnyDir = true;
            try {
              final List<FileSystemEntity> entities = await dir.list().toList();
              for (final entity in entities) {
                if (entity is File) {
                  final name = entity.uri.pathSegments.last;
                  if (name.startsWith('.')) continue;
                  if (!_isStatusPhoto(name) && !_isStatusVideo(name)) continue;

                  final String galleryDirName = _isStatusPhoto(name) ? 'Pictures' : 'DCIM';
                  final galleryFile = File('/storage/emulated/0/$galleryDirName/LoopHole/$name');
                  final cacheFile = File('${cacheDir.path}/$name');

                  final isDeleted = prefs.getBool('status_deleted_$name') ?? false;
                  if (!isDeleted && !await cacheFile.exists() && !await galleryFile.exists()) {
                    final bytes = await entity.readAsBytes();
                    await cacheFile.writeAsBytes(bytes, flush: true);
                    await prefs.setInt('status_cache_time_$name', DateTime.now().millisecondsSinceEpoch);
                  }
                }
              }
            } catch (e) {
              debugPrint("Error copying statuses from ${dir.path}: $e");
            }
          }
        }

        if (!foundAnyDir) {
          debugPrint("No WhatsApp Status directories found.");
        }

        try {
          if (await cacheDir.exists()) {
            final List<FileSystemEntity> cachedFiles = await cacheDir.list().toList();
            final now = DateTime.now().millisecondsSinceEpoch;
            const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

            for (final file in cachedFiles) {
              if (file is File) {
                final name = file.uri.pathSegments.last;
                final cacheTime = prefs.getInt('status_cache_time_$name') ?? now;
                if (now - cacheTime > sevenDaysMs) {
                  await file.delete();
                  await prefs.remove('status_cache_time_$name');
                }
              }
            }
          }
        } catch (e) {
          debugPrint("Error cleaning up statuses: $e");
        }
      }

      await _loadCachedFiles();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error in _scanAndCacheStatuses: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isStatusPhoto(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  bool _isStatusVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mkv');
  }



  Future<void> _loadCachedFiles() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/StatusSaver');
    if (!await cacheDir.exists()) return;

    try {
      final List<FileSystemEntity> files = await cacheDir.list().toList();
      final List<File> photos = [];
      final List<File> videos = [];
      final Map<String, int> cacheTimes = {};
      final prefs = await SharedPreferences.getInstance();

      for (final file in files) {
        if (file is File) {
          final path = file.path.toLowerCase();
          final name = file.uri.pathSegments.last;

          if (_isStatusPhoto(path)) {
            photos.add(file);
          } else if (_isStatusVideo(path)) {
            videos.add(file);
          }

          final cacheTime = prefs.getInt('status_cache_time_$name');
          if (cacheTime != null) {
            cacheTimes[name] = cacheTime;
          }
        }
      }

      final Map<String, DateTime> modTimes = {};
      await Future.wait(files.map((file) async {
        if (file is File) {
          try {
            modTimes[file.path] = await file.lastModified();
          } catch (_) {
            modTimes[file.path] = DateTime.fromMillisecondsSinceEpoch(0);
          }
        }
      }));

      photos.sort((a, b) {
        final timeA = modTimes[a.path] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = modTimes[b.path] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
      videos.sort((a, b) {
        final timeA = modTimes[a.path] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = modTimes[b.path] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });

      setState(() {
        _photoFiles = photos;
        _videoFiles = videos;
        _cacheTimes = cacheTimes;
      });
    } catch (e) {
      debugPrint("Error loading cached files: $e");
    }
  }

  Future<void> _saveStatus(File file) async {
    final name = file.uri.pathSegments.last;
    final isPhoto = _isStatusPhoto(name);
    final String galleryDirName = isPhoto ? 'Pictures' : 'DCIM';
    final galleryDir = Directory('/storage/emulated/0/$galleryDirName/LoopHole');
    
    try {
      String galleryPath;
      int fileSize = 0;

      if (Platform.isAndroid) {
        fileSize = await file.length();
        // Invoke native method to save to gallery using MediaStore (which handles Scoped Storage permissions)
        final String? resultPath = await _mediaChannel.invokeMethod<String>(
          'saveMediaToGallery',
          {
            'srcPath': file.path,
            'name': name,
          },
        );
        if (resultPath == null) {
          throw Exception("Failed to save media natively");
        }
        galleryPath = resultPath;

        // Delete cache file
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        // Fallback for non-Android platforms (if any)
        final bytes = await file.readAsBytes();
        fileSize = bytes.length;
        if (!await galleryDir.exists()) {
          await galleryDir.create(recursive: true);
        }
        galleryPath = '${galleryDir.path}/$name';
        final galleryFile = File(galleryPath);
        await galleryFile.writeAsBytes(bytes, flush: true);
        await file.delete();
      }

      // Clear cache timestamp from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('status_cache_time_$name');

      // Register in DownloadRepository pointing to the gallery path
      final item = DownloadItem()
        ..id = DateTime.now().millisecondsSinceEpoch.toString()
        ..url = 'status_saver_saved'
        ..title = 'Status_${name.split('.').first}'
        ..platform = 'whatsapp'
        ..quality = 'Status'
        ..filePath = galleryPath
        ..thumbnailUrl = ''
        ..status = DownloadItem.completed
        ..fileSize = fileSize
        ..createdAt = DateTime.now();
      await _repo.save(item);

      // Scan file ONLY once to make visible in gallery
      try {
        await _mediaChannel.invokeMethod('scanFile', {'path': galleryPath});
      } catch (e) {
        // scan error
      }

      // Reload cached lists
      await _loadCachedFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status saved to Library & Gallery!'),
            backgroundColor: AppColors.neonPurple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving status: $e'),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteStatus(File file) async {
    try {
      final name = file.uri.pathSegments.last;
      await file.delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('status_cache_time_$name');
      await prefs.setBool('status_deleted_$name', true);
      await _loadCachedFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status deleted from cache.'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting status: $e'),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedStatuses() async {
    if (_selectedFileNames.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/StatusSaver');
      
      int deletedCount = 0;
      for (final filename in _selectedFileNames) {
        final file = File('${cacheDir.path}/$filename');
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
        }
        await prefs.remove('status_cache_time_$filename');
        await prefs.setBool('status_deleted_$filename', true);
      }

      setState(() {
        _selectedFileNames.clear();
      });

      await _loadCachedFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount status(es) deleted from cache.'),
            backgroundColor: Colors.grey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting statuses: $e'),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }



  String _getExpirationText(String filename) {
    final cacheTime = _cacheTimes[filename];
    if (cacheTime == null) return 'Expires soon';

    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cacheTime));
    final remainingDays = 7 - diff.inDays;

    if (remainingDays <= 0) return 'Expires today';
    return 'Expires in $remainingDays days';
  }

  Widget _buildGrid(List<File> files, bool isVideo) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: context.rSize(48), color: Colors.grey),
            SizedBox(height: context.rSize(16)),
            Text(
              'NO STATUSES FOUND',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF888888),
                fontSize: context.rFont(14),
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),

          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(context.rSize(16)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: context.rSize(12),
        mainAxisSpacing: context.rSize(12),
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final filename = file.uri.pathSegments.last;
        final isSelected = _selectedFileNames.contains(filename);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(context.rSize(16)),
            border: Border.all(
              color: isSelected 
                  ? AppColors.neonPurple 
                  : AppColors.neonPurple.withValues(alpha: 0.15), 
              width: isSelected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onLongPress: () {
              setState(() {
                if (_selectedFileNames.contains(filename)) {
                  _selectedFileNames.remove(filename);
                } else {
                  _selectedFileNames.add(filename);
                }
              });
            },
            onTap: () {
              if (_selectedFileNames.isNotEmpty) {
                setState(() {
                  if (isSelected) {
                    _selectedFileNames.remove(filename);
                  } else {
                    _selectedFileNames.add(filename);
                  }
                });
              } else {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    opaque: false,
                    barrierColor: Colors.black,
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return FadeTransition(
                        opacity: animation,
                        child: StatusPreviewOverlay(
                          file: file,
                          isVideo: isVideo,
                          expirationText: _getExpirationText(filename),
                          onSave: () => _saveStatus(file),
                          onDelete: () => _deleteStatus(file),
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 250),
                    reverseTransitionDuration: const Duration(milliseconds: 200),
                  ),
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                isVideo
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoThumbnailWidget(path: file.path),
                          Center(
                            child: Container(
                              padding: EdgeInsets.all(context.rSize(12)),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.8), width: 1.5),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: context.rSize(28),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          color: const Color(0xFF151515),
                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      ),
                if (_selectedFileNames.isNotEmpty)
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: isSelected 
                          ? AppColors.neonPurple.withValues(alpha: 0.25)
                          : Colors.black45,
                    ),
                  ),
                if (_selectedFileNames.isNotEmpty)
                  Positioned(
                    top: context.rSize(8),
                    right: context.rSize(8),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(context.rSize(2)),
                      child: Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? AppColors.neonPurple : Colors.white70,
                        size: context.rSize(24),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isSelectionMode = _selectedFileNames.isNotEmpty;
    final List<File> activeFiles = _tabController.index == 0 ? _photoFiles : _videoFiles;
    final bool allSelected = activeFiles.isNotEmpty && activeFiles.every((f) => _selectedFileNames.contains(f.uri.pathSegments.last));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: const Color(0xFF0F0F0F),
              elevation: 4,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedFileNames.clear();
                  });
                },
              ),
              title: Text(
                '${_selectedFileNames.length} SELECTED',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: context.rFont(16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                    color: AppColors.neonPurple,
                  ),
                  tooltip: allSelected ? 'Deselect All' : 'Select All',
                  onPressed: () {
                    setState(() {
                      if (allSelected) {
                        for (final f in activeFiles) {
                          _selectedFileNames.remove(f.uri.pathSegments.last);
                        }
                      } else {
                        for (final f in activeFiles) {
                          _selectedFileNames.add(f.uri.pathSegments.last);
                        }
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Delete Selected',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF151515),
                        title: Text(
                          'DELETE STATUSES',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: context.rFont(16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          'Are you sure you want to delete ${_selectedFileNames.length} selected status(es) from cache?',
                          style: TextStyle(color: Colors.grey, fontSize: context.rFont(14)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _deleteSelectedStatuses();
                            },
                            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(width: context.rSize(8)),
              ],
            )
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'STATUS SAVER',
                  style: GoogleFonts.orbitron(
                    color: AppColors.neonPurple,
                    fontSize: context.rFont(18),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              actions: [
                if (_isSaverEnabled)
                  IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: context.rSize(20),
                            height: context.rSize(20),
                            child: const CircularProgressIndicator(color: Colors.grey, strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, color: Colors.grey),
                    onPressed: _scanAndCacheStatuses,
                  ),
                Switch(
                  value: _isSaverEnabled,
                  onChanged: _toggleSaver,
                  activeThumbColor: AppColors.neonPurple,
                  activeTrackColor: AppColors.neonPurple.withValues(alpha: 0.3),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                ),
                SizedBox(width: context.rSize(8)),
              ],
            ),
      body: SafeArea(
        child: !_isSaverEnabled
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: context.rSize(64), color: Colors.grey),
                    SizedBox(height: context.rSize(24)),
                    Text(
                      'Status Saver is turned off.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: context.rFont(15)),
                    ),
                    SizedBox(height: context.rSize(8)),
                    Text(
                      'Turn it on to save viewed statuses.',
                      style: TextStyle(color: Colors.grey, fontSize: context.rFont(12)),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.neonPurple,
                    labelColor: AppColors.neonPurple,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: context.rFont(14)),
                    unselectedLabelStyle: TextStyle(fontSize: context.rFont(14)),
                    tabs: const [
                      Tab(text: 'PHOTOS'),
                      Tab(text: 'VIDEOS'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGrid(_photoFiles, false),
                        _buildGrid(_videoFiles, true),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class StatusPreviewOverlay extends StatefulWidget {
  final File file;
  final bool isVideo;
  final String expirationText;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const StatusPreviewOverlay({
    super.key,
    required this.file,
    required this.isVideo,
    required this.expirationText,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<StatusPreviewOverlay> createState() => _StatusPreviewOverlayState();
}

class _StatusPreviewOverlayState extends State<StatusPreviewOverlay> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(widget.file)
        ..initialize().then((_) {
          if (mounted && _videoController != null) {
            setState(() {
              _isInitialized = true;
            });
            _videoController?.play();
            _videoController?.setLooping(true);
          }
        }).catchError((e) {
          debugPrint('Video controller init error: $e');
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Large Preview of Status
            Center(
              child: widget.isVideo
                  ? (_isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator(color: AppColors.neonPurple))
                  : Image.file(
                      widget.file,
                      fit: BoxFit.contain,
                    ),
            ),
            
            // 2. Play/Pause Gesture Detector Overlay for Video (under the button controls)
            if (widget.isVideo && _isInitialized)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                    });
                  },
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: EdgeInsets.all(context.rSize(16)),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _videoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: context.rSize(48),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Expiration Badge (Top Left)
            Positioned(
              top: context.rSize(16),
              left: context.rSize(16),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: context.rSize(12), vertical: context.rSize(6)),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(context.rSize(20)),
                  border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.3)),
                ),
                child: Text(
                  widget.expirationText,
                  style: TextStyle(color: Colors.white, fontSize: context.rFont(12), fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // 4. Close Button (Top Right) - On top of Play/Pause gesture detector in Stack
            Positioned(
              top: context.rSize(16),
              right: context.rSize(16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(context.rSize(24)),
                  child: Container(
                    padding: EdgeInsets.all(context.rSize(8)),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: context.rSize(24),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Bottom Action Buttons: [Save Status] (center-bottom) and [Delete] (bottom-right)
            Positioned(
              bottom: context.rSize(24),
              left: context.rSize(24),
              right: context.rSize(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: context.rSize(48)), // Symmetry spacer matching Delete button size
                  
                  // Save Button
                  Expanded(
                    child: Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonPurple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: context.rSize(32), vertical: context.rSize(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.rSize(30)),
                          ),
                          shadowColor: AppColors.neonPurpleGlow,
                          elevation: 8,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onSave();
                        },
                        icon: Icon(Icons.download_rounded, size: context.rSize(20)),
                        label: Text(
                          'SAVE STATUS',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: context.rFont(14)),
                        ),
                      ),
                    ),
                  ),
                  
                  // Delete Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDelete();
                      },
                      borderRadius: BorderRadius.circular(context.rSize(24)),
                      child: Container(
                        padding: EdgeInsets.all(context.rSize(12)),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: context.rSize(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
