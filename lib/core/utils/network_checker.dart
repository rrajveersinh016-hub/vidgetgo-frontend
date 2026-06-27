import 'dart:io';

class NetworkChecker {
  /// Quick check to confirm current active routing paths are capable of establishing network sockets.
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
