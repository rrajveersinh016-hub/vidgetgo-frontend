enum PlatformType { youtube, instagram, facebook, pinterest, unknown }

PlatformType detectPlatform(String url) {
  final uri = Uri.parse(url.toLowerCase());
  final host = uri.host;
  final path = uri.path;
  
  // YouTube
  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    if (path.contains('/watch') || 
        path.contains('/shorts/') || 
        host == 'youtu.be') {
      return PlatformType.youtube;
    }
  }
  
  // Instagram  
  if (host.contains('instagram.com')) {
    if (path.contains('/p/') || 
        path.contains('/reel/') || 
        path.contains('/tv/')) {
      return PlatformType.instagram;
    }
  }
  
  // Facebook
  if (host.contains('facebook.com') || host.contains('fb.watch')) {
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
