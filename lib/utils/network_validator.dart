// lib/utils/network_validator.dart
//
// SECURITY — SSRF MITIGATION:
// All UPnP/DLNA target IPs must belong to a private subnet before any
// HTTP packet is dispatched. This prevents Server-Side Request Forgery.

class NetworkValidator {
  NetworkValidator._();

  /// Accepted RFC-1918 private ranges:
  ///   10.0.0.0/8   → 10.x.x.x
  ///   172.16.0.0/12 → 172.16.x.x – 172.31.x.x
  ///   192.168.0.0/16 → 192.168.x.x
  static bool isPrivateIp(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length != 4) return false;
    final nums = parts.map(int.tryParse).toList();
    if (nums.any((n) => n == null || n < 0 || n > 255)) return false;

    final a = nums[0]!;
    final b = nums[1]!;

    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;

    return false; // Public IP — reject
  }

  /// Validates a full URI — scheme must be http (LAN UPnP) and host must
  /// be a private IP. HTTPS external calls are handled by the HTTP client.
  static bool isValidUpnpTarget(String? uri) {
    if (uri == null || uri.isEmpty) return false;
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return false;
    if (parsed.scheme != 'http' && parsed.scheme != 'https') return false;
    return isPrivateIp(parsed.host);
  }

  /// Returns a TLS-enforcing HttpClient description for external APIs.
  /// Actual enforcement is done in the HTTP service via dart:io SecurityContext.
  static bool isSecureExternalUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https';
  }
}
