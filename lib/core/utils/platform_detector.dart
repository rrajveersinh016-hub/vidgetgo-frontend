enum PlatformType { youtube, instagram, facebook, pinterest, unknown }

PlatformType detectPlatform(String url) {
  final cleanUrl = url.trim().toLowerCase();
  final uri = Uri.tryParse(cleanUrl);
  if (uri == null) return PlatformType.unknown;
  final host = uri.host;
  
  // YouTube
  if (host.contains('youtube.com') || host.contains('youtu.be') || host.contains('youtube.be')) {
    return PlatformType.youtube;
  }
  
  // Instagram  
  if (host.contains('instagram.com')) {
    return PlatformType.instagram;
  }
  
  // Facebook
  if (host.contains('facebook.com') || host.contains('fb.watch') || host.contains('fb.com')) {
    return PlatformType.facebook;
  }
  
  // Pinterest
  if (host.contains('pinterest.com') || host.contains('pin.it')) {
    return PlatformType.pinterest;
  }
  
  return PlatformType.unknown;
}

String platformName(PlatformType type) {
  switch (type) {
    case PlatformType.youtube: return 'Video';
    case PlatformType.instagram: return 'Reel';
    case PlatformType.facebook: return 'Social';
    case PlatformType.pinterest: return 'Pin';
    default: return 'Unknown';
  }
}
