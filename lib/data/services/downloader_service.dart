import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'review_manager.dart';
import 'remote_config_service.dart';

class DownloaderService {
  final Dio _dio = Dio();

  Future<Map<String, dynamic>> _fetchPinterestClientSide(String url) async {
    final httpClient = HttpClient();
    try {
      String targetUrl = url;
      if (url.contains('pin.it')) {
        final request = await httpClient.headUrl(Uri.parse(url));
        request.followRedirects = false;
        final response = await request.close();
        final redirectUrl = response.headers.value('location');
        if (redirectUrl != null) {
          targetUrl = redirectUrl;
        }
      }

      final request = await httpClient.getUrl(Uri.parse(targetUrl));
      request.headers.set('User-Agent',
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
      request.headers.set('Accept', '*/*');
      request.headers.set('Referer', 'https://pinterest.com');

      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception(
            'Pinterest fetch failed with status ${response.statusCode}');
      }

      final html = await response.transform(utf8.decoder).join();
      final cleanHtml = html.replaceAll('\\/', '/');

      final regex = RegExp(
          r'https://[a-zA-Z0-9.-]+\.pinimg\.com/[a-zA-Z0-9_/.-]+\.mp4');
      final matches =
          regex.allMatches(cleanHtml).map((m) => m.group(0)!).toSet().toList();

      if (matches.isEmpty) {
        throw Exception('No video streams found on Pinterest page');
      }

      String bestMatch = matches.first;
      for (final match in matches) {
        if (match.contains('720p') ||
            match.contains('h264') ||
            match.contains('1080p')) {
          bestMatch = match;
          break;
        }
      }

      return {
        'status': 'stream',
        'url': bestMatch,
        'title': 'Saved Video',
        'thumbnail': '',
        'quality': bestMatch.contains('720p') ? '720p HD' : 'best',
        'hasAudio': true,
      };
    } finally {
      httpClient.close();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public entry point — always returns a List so callers handle single items
  // and carousels uniformly.
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fetchVideoInfo(String url) async {
    try {
      final bool isYouTube =
          url.contains('youtube.com') || url.contains('youtu.be');
      final bool isPinterest =
          url.contains('pinterest.com') || url.contains('pin.it');

      if (isYouTube) {
        return await _fetchYouTubeInfo(url);
      }

      if (isPinterest) {
        try {
          return await _fetchPinterestClientSide(url);
        } catch (e) {
          // Fallback to backend
        }
      }

      final String primaryUrl = RemoteConfigService().backendUrl;
      final String backupUrl = RemoteConfigService().backupUrl;

      // 1. Try Primary Server
      try {
        final response = await _dio.get(
          '$primaryUrl/extract',
          queryParameters: {'url': url},
          options: Options(
            sendTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 12),
            headers: {
              'x-api-key': RemoteConfigService().apiKey,
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          return _parseBackendResponse(response.data as Map<String, dynamic>);
        }
        throw Exception('Primary failed with status: ${response.statusCode}');
      } catch (primaryError) {
        // 2. Failover: Try Backup Server
        try {
          final response = await _dio.get(
            '$backupUrl/extract',
            queryParameters: {'url': url},
            options: Options(
              sendTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 25),
              headers: {
                'x-api-key': RemoteConfigService().apiKey,
              },
            ),
          );

          if (response.statusCode == 200 && response.data != null) {
            return _parseBackendResponse(response.data as Map<String, dynamic>);
          }

          final errorData = response.data;
          throw Exception(
              errorData is Map ? (errorData['detail'] ?? 'Backend error') : 'Backup failed with status: ${response.statusCode}');
        } on DioException catch (e) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            throw Exception('Extraction timed out. This account might be private or the link is invalid.');
          }
          throw Exception(e.response?.data is Map 
              ? (e.response?.data['detail'] ?? 'Network error')
              : 'Network error: ${e.message}');
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Extraction timed out. This account might be private or the link is invalid.');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Parses a backend response (single item OR carousel) → returns Map.
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _parseBackendResponse(Map<String, dynamic> data) {
    final List<dynamic>? mediaUrls = data['media_urls'] as List<dynamic>?;
    final String topMediaType = (data['media_type'] as String? ?? '').toLowerCase();
    final String title = data['Video Title'] ?? data['title'] ?? '';
    final String thumbnail = data['Thumbnail URL'] ?? data['thumbnail'] ?? '';

    // 1. Primary path: Parse media_urls list (Instaloader/Carousel/Modern backends)
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      final String url = (mediaUrls[0] as String? ?? '').trim();
      if (url.isNotEmpty) {
        // Sniff if this specific URL is a photo
        final urlPath = url.toLowerCase().split('?').first;
        final bool isPhotoUrl = urlPath.endsWith('.jpg') ||
            urlPath.endsWith('.jpeg') ||
            urlPath.endsWith('.png') ||
            urlPath.endsWith('.webp') ||
            urlPath.endsWith('.heic') ||  // Instagram CDN uses .heic before query params
            topMediaType == 'photo' ||
            topMediaType == 'image' ||
            topMediaType == 'carousel'; // our backend returns 'carousel' for all IG photos

        final String baseTitle = title.isNotEmpty ? title : (isPhotoUrl ? 'photo' : 'video');

        return {
          'status': 'stream',
          'url': url,
          'all_media_urls': mediaUrls,
          'title': baseTitle,
          'thumbnail': thumbnail,
          'quality': isPhotoUrl ? 'Original' : 'best',
          'hasAudio': !isPhotoUrl,
          'media_type': isPhotoUrl ? 'photo' : 'video',
        };
      }
    }

    // 2. Fallback path A: Parse Formats array (legacy compatibility)
    final List<dynamic>? formats = data['Formats'] as List<dynamic>?;
    if (formats != null && formats.isNotEmpty) {
      Map<String, dynamic>? bestFormat;
      for (final f in formats) {
        final format = f as Map<String, dynamic>;
        if (format['Extension'] == 'mp4' && format['Has Audio'] == true) {
          bestFormat = format;
        }
      }

      bestFormat ??= formats.firstWhere(
        (f) => (f as Map)['Has Audio'] == true,
        orElse: () => formats.last,
      ) as Map<String, dynamic>;

      final downloadUrl = (bestFormat['Direct Download Link'] as String? ?? '').trim();
      if (downloadUrl.isNotEmpty) {
        final bool isPhoto = topMediaType == 'photo' || topMediaType == 'image';
        final String baseTitle = title.isNotEmpty ? title : (isPhoto ? 'photo' : 'video');
        return {
          'status': 'stream',
          'url': downloadUrl,
          'title': baseTitle,
          'thumbnail': thumbnail,
          'quality': isPhoto ? 'Original' : (bestFormat['Resolution'] ?? 'best'),
          'hasAudio': isPhoto ? false : (bestFormat['Has Audio'] ?? false),
          'media_type': isPhoto ? 'photo' : 'video',
        };
      }
    }

    // 3. Fallback path B: Direct url key at top-level
    final String rawUrl = (data['url'] as String? ??
            data['direct_url'] as String? ??
            data['download_url'] as String? ??
            '')
        .trim();
    if (rawUrl.isNotEmpty) {
      final bool isPhoto = topMediaType == 'photo' || topMediaType == 'image';
      final String baseTitle = title.isNotEmpty ? title : (isPhoto ? 'photo' : 'video');
      return {
        'status': 'stream',
        'url': rawUrl,
        'title': baseTitle,
        'thumbnail': thumbnail,
        'quality': isPhoto ? 'Original' : 'best',
        'hasAudio': !isPhoto,
        'media_type': isPhoto ? 'photo' : 'video',
      };
    }

    throw Exception('Could not extract media – no download URL found');
  }

  Future<Map<String, dynamic>> _fetchYouTubeInfo(String url) async {
    final ytClient = yt.YoutubeExplode();
    try {
      final videoId = _extractYouTubeId(url);
      final video = await ytClient.videos.get(videoId);
      final manifest = await ytClient.videos.streamsClient.getManifest(
        video.id,
        ytClients: [yt.YoutubeApiClient.androidVr],
      );

      // Get best video-only stream (cap at 1080p, AVC/H.264 only)
      final videoStreams = manifest.videoOnly.where((s) =>
          (s.container.name == 'mp4' ||
              s.container.toString().contains('mp4')) &&
          s.videoCodec.toLowerCase().contains('avc'));
      var videoStream =
          videoStreams.isNotEmpty ? videoStreams.first : manifest.videoOnly.first;

      for (final stream in videoStreams) {
        if (stream.videoResolution.height > videoStream.videoResolution.height &&
            stream.videoResolution.height <= 1080) {
          videoStream = stream;
        }
      }

      // Get best audio stream (MP4/AAC preferred)
      final audioStreams = manifest.audioOnly.where((s) =>
          s.container.name == 'mp4' ||
          s.container.toString().contains('mp4') ||
          s.container.name == 'aac' ||
          s.container.toString().contains('aac'));
      final audioStream = audioStreams.isNotEmpty
          ? audioStreams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();

      final String videoUrl = videoStream.url.toString();
      final String audioUrl = audioStream.url.toString();

      final isShort =
          url.contains('/shorts/') || url.contains('shorts');
      return {
        'status': 'adaptive',
        'url': '$videoUrl|$audioUrl|$videoId|${isShort ? 'short' : 'video'}',
        'title': video.title,
        'thumbnail': video.thumbnails.highResUrl,
        'quality': '${videoStream.videoResolution.height}p Full HD',
        'hasAudio': true,
      };
    } catch (e) {
      // debugPrint('Adaptive fetch error: $e');
      return await _fetchYouTubeFallback(url);
    } finally {
      ytClient.close();
    }
  }

  // Fallback method using youtube_explode_dart
  Future<Map<String, dynamic>> _fetchYouTubeFallback(String url) async {
    final ytClient = yt.YoutubeExplode();
    try {
      final videoId = _extractYouTubeId(url);
      final video = await ytClient.videos.get(videoId);
      final manifest =
          await ytClient.videos.streamsClient.getManifest(videoId);

      // Get best muxed (has audio, lower quality but guaranteed)
      var streamInfo = manifest.muxed.first;
      for (final stream in manifest.muxed) {
        if (stream.videoResolution.height > streamInfo.videoResolution.height) {
          streamInfo = stream;
        }
      }

      return {
        'status': 'stream',
        'url': streamInfo.url.toString(),
        'title': video.title,
        'thumbnail': video.thumbnails.highResUrl,
        'quality': streamInfo.qualityLabel,
        'hasAudio': true,
      };
    } finally {
      ytClient.close();
    }
  }

  String _extractYouTubeId(String url) {
    final patterns = [
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]{11})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1)!;
    }
    return url;
  }

  String _getReferer(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return 'https://www.instagram.com/';
      case 'facebook':
        return 'https://www.facebook.com/';
      case 'pinterest':
        return 'https://www.pinterest.com/';
      default:
        return 'https://www.google.com/';
    }
  }

  Future<String> downloadFile(
    String downloadUrl,
    String title,
    String platform,
    Function(double) onProgress, {
    bool audioOnly = false,
    bool isPhoto = false,
  }) async {
    final externalDir = await getExternalStorageDirectory();
    final dir = Directory('${externalDir?.path ?? '/storage/emulated/0'}/Download/LoopHole');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Clean filename
    String cleanTitle = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();

    if (cleanTitle.isEmpty) cleanTitle = isPhoto ? 'photo' : 'video';
    if (cleanTitle.length > 50) cleanTitle = cleanTitle.substring(0, 50);

    String extension;
    if (audioOnly) {
      extension = 'm4a';
    } else if (isPhoto) {
      extension = _getExtensionFromUrl(downloadUrl);
    } else {
      extension = 'mp4';
    }
    final filename =
        '${cleanTitle}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final filePath = '${dir.path}/$filename';

    try {
      if (downloadUrl.contains('|')) {
        final urls = downloadUrl.split('|');
        if (urls.length >= 2) {
          final videoUrl = urls[0];
          final audioUrl = urls[1];
          final String? videoId = urls.length >= 3 ? urls[2] : null;
          final bool isRegularVideo =
              urls.length == 4 ? urls[3] == 'video' : false;

          if (audioOnly) {
            if (platform.toLowerCase() == 'youtube' &&
                videoId != null &&
                isRegularVideo) {
              final ytClient = yt.YoutubeExplode();
              try {
                final manifest =
                    await ytClient.videos.streamsClient.getManifest(
                  videoId,
                  ytClients: [yt.YoutubeApiClient.androidVr],
                );

                final audioStreams = manifest.audioOnly.where((s) =>
                    s.container.name == 'mp4' ||
                    s.container.toString().contains('mp4') ||
                    s.container.name == 'aac' ||
                    s.container.toString().contains('aac'));
                final audioStream = audioStreams.isNotEmpty
                    ? audioStreams.withHighestBitrate()
                    : manifest.audioOnly.withHighestBitrate();
                final freshAudioUrl = audioStream.url.toString();

                await _downloadStream(freshAudioUrl, filePath, platform,
                    onProgress,
                    isRegularYTVideo: true);
              } finally {
                ytClient.close();
              }
            } else {
              await _downloadStream(audioUrl, filePath, platform, onProgress);
            }
          } else {
            // Video + Audio flow
            final tempDir = await getTemporaryDirectory();
            final tempVideoPath =
                '${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
            final tempAudioPath =
                '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

            if (platform.toLowerCase() == 'youtube' &&
                videoId != null &&
                isRegularVideo) {
              // YouTube CDN can drop/throttle mid-stream. Retry up to 3 times,
              // fetching a completely fresh manifest each attempt so URLs are
              // never stale. Failures are silent — UI never resets to idle.
              const maxAttempts = 3;
              Exception? lastError;

              for (int attempt = 1; attempt <= maxAttempts; attempt++) {
                lastError = null;
                // Reset temp files before each attempt
                final tempVideoFile = File(tempVideoPath);
                final tempAudioFile = File(tempAudioPath);
                if (await tempVideoFile.exists()) await tempVideoFile.delete();
                if (await tempAudioFile.exists()) await tempAudioFile.delete();

                // Reset progress bar to 0 at the start of each attempt
                onProgress(0.01);

                final ytClient = yt.YoutubeExplode();
                try {
                  final manifest =
                      await ytClient.videos.streamsClient.getManifest(
                    videoId,
                    ytClients: [yt.YoutubeApiClient.androidVr],
                  );

                  final videoStreams = manifest.videoOnly.where((s) =>
                      (s.container.name == 'mp4' ||
                          s.container.toString().contains('mp4')) &&
                      s.videoCodec.toLowerCase().contains('avc'));
                  var videoStream = videoStreams.isNotEmpty
                      ? videoStreams.first
                      : manifest.videoOnly.first;
                  for (final stream in videoStreams) {
                    if (stream.videoResolution.height >
                            videoStream.videoResolution.height &&
                        stream.videoResolution.height <= 1080) {
                      videoStream = stream;
                    }
                  }

                  final audioStreams = manifest.audioOnly.where((s) =>
                      s.container.name == 'mp4' ||
                      s.container.toString().contains('mp4') ||
                      s.container.name == 'aac' ||
                      s.container.toString().contains('aac'));
                  final audioStream = audioStreams.isNotEmpty
                      ? audioStreams.withHighestBitrate()
                      : manifest.audioOnly.withHighestBitrate();

                  final freshVideoUrl = videoStream.url.toString();
                  final freshAudioUrl = audioStream.url.toString();

                  await _downloadStream(
                      freshVideoUrl, tempVideoPath, platform, (p) {
                    onProgress(p * 0.5);
                  }, isRegularYTVideo: true);

                  await _downloadStream(
                      freshAudioUrl, tempAudioPath, platform, (p) {
                    onProgress(0.5 + p * 0.4);
                  }, isRegularYTVideo: true);

                  // Success — break out of retry loop
                  break;
                } catch (e) {
                  lastError = Exception('YouTube attempt $attempt failed: $e');
                  debugPrint('YouTube download attempt $attempt failed: $e');
                  ytClient.close();
                  if (attempt < maxAttempts) {
                    // Brief pause before next attempt, keep progress visible
                    onProgress(0.05);
                    await Future.delayed(const Duration(seconds: 2));
                  }
                  continue;
                } finally {
                  ytClient.close();
                }
              }

              // If all attempts failed, throw the last error
              if (lastError != null) throw lastError;
            } else {
              await _downloadStream(videoUrl, tempVideoPath, platform, (p) {
                onProgress(p * 0.5);
              });

              await _downloadStream(audioUrl, tempAudioPath, platform, (p) {
                onProgress(0.5 + p * 0.4);
              });
            }

            // Simulate merge progress (90%→99%) so the bar doesn't freeze.
            // The actual merge is a blocking native call with no callbacks.
            onProgress(0.90);
            final mergeProgressTimer = Stream.periodic(
              const Duration(milliseconds: 500),
              (i) => 0.90 + (i + 1) * 0.01,
            ).take(9).listen((p) => onProgress(p));

            try {
              await _mergeVideoAndAudio(tempVideoPath, tempAudioPath, filePath);
            } finally {
              await mergeProgressTimer.cancel();
            }

          }

          onProgress(1.0);

          final savedFile = File(filePath);
          final fileSize = await savedFile.length();
          if (fileSize < 1000) {
            if (await savedFile.exists()) await savedFile.delete();
            throw Exception(
                'File too small: $fileSize bytes - download failed');
          }

          // Save to system gallery (DCIM for video/photo, Music for audio).
          // Files in /Android/data/ are invisible to gallery/music apps on Android 10+.
          String galleryPath = filePath;
          try {
            const channel = MethodChannel('com.loophole.app/media');
            final result = await channel.invokeMethod<String>(
              'saveMediaToGallery',
              {'srcPath': filePath, 'name': filename},
            );
            if (result != null && result.isNotEmpty) {
              galleryPath = result;
            }
          } catch (e) {
            // Gallery save failed — library still works from private path
            debugPrint('saveMediaToGallery error: $e');
          }


          await ReviewManager.incrementDownloadCount();
          await ReviewManager.showReviewIfEligible();

          return galleryPath;
        }
      }

      await _downloadStream(downloadUrl, filePath, platform, onProgress);

      final savedFile = File(filePath);
      final fileSize = await savedFile.length();
      if (fileSize < 1000) {
        if (await savedFile.exists()) await savedFile.delete();
        throw Exception('File too small: $fileSize bytes - download failed');
      }

      // Save to system gallery (DCIM for video/photo, Music for audio).
      // Files in /Android/data/ are invisible to gallery/music apps on Android 10+.
      String galleryPath = filePath;
      try {
        const channel = MethodChannel('com.loophole.app/media');
        final result = await channel.invokeMethod<String>(
          'saveMediaToGallery',
          {'srcPath': filePath, 'name': filename},
        );
        if (result != null && result.isNotEmpty) {
          galleryPath = result;
        }
      } catch (e) {
        // Gallery save failed — library still works from private path
        debugPrint('saveMediaToGallery error: $e');
      }

      await ReviewManager.incrementDownloadCount();
      await ReviewManager.showReviewIfEligible();

      return galleryPath;
    } catch (e) {
      try {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _downloadStream(
    String url,
    String savePath,
    String platform,
    Function(double) onProgress, {
    bool isRegularYTVideo = false,
  }) async {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await httpClient.getUrl(Uri.parse(url));

      if (platform.toLowerCase() == 'pinterest') {
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
        request.headers.set('Accept-Encoding', 'gzip, deflate, br');
        request.headers.set('Connection', 'keep-alive');
      } else {
        request.headers.set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      }

      request.headers.set('Accept', '*/*');

      if (!isRegularYTVideo) {
        request.headers.set('Referer', _getReferer(platform));
      }

      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception(
            'Stream download failed: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      // Add a timeout of 60 seconds. If no data chunk is received for 60s,
      // it throws a TimeoutException, breaking the silent hang.
      await for (final chunk in response.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
    } finally {
      httpClient.close();
    }
  }

  Future<void> _mergeVideoAndAudio(
    String videoPath,
    String audioPath,
    String outputPath,
  ) async {
    try {
      const channel = MethodChannel('com.loophole.app/media');
      await channel.invokeMethod('mergeVideoAndAudio', {
        'videoPath': videoPath,
        'audioPath': audioPath,
        'outputPath': outputPath,
      });
    } finally {
      // Clean up temporary files immediately
      try {
        final vFile = File(videoPath);
        final aFile = File(audioPath);
        if (await vFile.exists()) await vFile.delete();
        if (await aFile.exists()) await aFile.delete();
      } catch (e) {
        // debugPrint('Temp file cleanup error: $e');
      }
    }
  }

  String _getExtensionFromUrl(String url) {
    final uri = Uri.parse(url.split('?').first);
    final path = uri.path.toLowerCase();
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.webp')) return 'webp';
    if (path.endsWith('.gif')) return 'gif';
    return 'jpg'; // default fallback
  }
}
