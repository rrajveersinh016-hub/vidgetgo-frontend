bool isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && 
           (uri.scheme == 'http' || uri.scheme == 'https') && 
           uri.host.isNotEmpty;
  } catch (_) {
    return false;
  }
}
