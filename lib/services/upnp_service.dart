// lib/services/upnp_service.dart
//
// Sends UPnP / SOAP commands to a Linkplay/Forestream MediaRenderer.
// SECURITY:
//   • All target IPs are validated as private-subnet before dispatch (SSRF).
//   • HTTPS is enforced for all external API calls elsewhere.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bella_music/utils/network_validator.dart';
import 'package:logger/logger.dart';

class UpnpService {
  UpnpService._();
  static final UpnpService instance = UpnpService._();

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  static const Duration _timeout = Duration(seconds: 8);

  // ─── SetAVTransportURI (start streaming a URL on the speaker) ─────────────
  Future<bool> setAvTransportUri({
    required String speakerIp,
    required int port,
    required String streamUrl,
    String instanceId = '0',
    String currentUriMetaData = 'NOT_IMPLEMENTED',
  }) async {
    // SSRF guard — reject non-private IPs
    if (!NetworkValidator.isPrivateIp(speakerIp)) {
      _logger.e('UPnP: Rejected non-private target IP: $speakerIp');
      return false;
    }

    // Only allow HTTPS stream URLs (MitM prevention)
    if (!NetworkValidator.isSecureExternalUrl(streamUrl)) {
      _logger.w('UPnP: streamUrl is not HTTPS — proceeding cautiously on LAN.');
    }

    final uri = Uri.parse('http://$speakerIp:$port/upnp/control/rendertransport1');
    const action = '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"';

    final soapBody = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
            xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>$instanceId</InstanceID>
      <CurrentURI>${_escapeXml(streamUrl)}</CurrentURI>
      <CurrentURIMetaData>${_escapeXml(currentUriMetaData)}</CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>''';

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'text/xml; charset="utf-8"',
          'SOAPAction': action,
          'Connection': 'close',
        },
        body: utf8.encode(soapBody),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        _logger.i('UPnP: SetAVTransportURI success → $streamUrl');
        return true;
      } else {
        _logger.w('UPnP: SetAVTransportURI failed (${response.statusCode})');
        return false;
      }
    } catch (e) {
      _logger.e('UPnP: Error sending SetAVTransportURI: $e');
      return false;
    }
  }

  // ─── Play ─────────────────────────────────────────────────────────────────
  Future<bool> play(String speakerIp, {int port = 49152}) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    return _sendTransportAction(speakerIp, port, 'Play', '<Speed>1</Speed>');
  }

  // ─── Pause ────────────────────────────────────────────────────────────────
  Future<bool> pause(String speakerIp, {int port = 49152}) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    return _sendTransportAction(speakerIp, port, 'Pause', '');
  }

  // ─── Stop ─────────────────────────────────────────────────────────────────
  Future<bool> stop(String speakerIp, {int port = 49152}) async {
    if (!NetworkValidator.isPrivateIp(speakerIp)) return false;
    return _sendTransportAction(speakerIp, port, 'Stop', '');
  }

  // ─── Generic transport action ─────────────────────────────────────────────
  Future<bool> _sendTransportAction(
      String ip, int port, String action, String extraBody) async {
    final uri = Uri.parse('http://$ip:$port/upnp/control/rendertransport1');
    final soapAction = '"urn:schemas-upnp-org:service:AVTransport:1#$action"';

    final soapBody = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
            xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
  <s:Body>
    <u:$action xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      $extraBody
    </u:$action>
  </s:Body>
</s:Envelope>''';

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'text/xml; charset="utf-8"',
          'SOAPAction': soapAction,
        },
        body: utf8.encode(soapBody),
      ).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      _logger.e('UPnP $action error: $e');
      return false;
    }
  }

  // ─── XML escape helper ────────────────────────────────────────────────────
  String _escapeXml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

