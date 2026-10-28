import 'package:localsend_app/util/native/tailscale_helper.dart';
import 'package:test/test.dart';

void main() {
  group('isTailscaleAddress', () {
    test('matches the CGNAT range', () {
      expect(isTailscaleAddress('100.64.0.1'), isTrue);
      expect(isTailscaleAddress('100.101.102.103'), isTrue);
      expect(isTailscaleAddress('100.127.255.254'), isTrue);
    });

    test('rejects other addresses', () {
      expect(isTailscaleAddress('100.63.0.1'), isFalse);
      expect(isTailscaleAddress('100.128.0.1'), isFalse);
      expect(isTailscaleAddress('192.168.1.5'), isFalse);
      expect(isTailscaleAddress('fd7a:115c:a1e0::1'), isFalse);
      expect(isTailscaleAddress('not an ip'), isFalse);
    });
  });

  group('parseTailscalePeerIps', () {
    test('returns the IPv4 addresses of online peers only', () {
      const json = '''
{
  "Self": {"Online": true, "TailscaleIPs": ["100.100.100.1"]},
  "Peer": {
    "a": {"Online": true, "TailscaleIPs": ["100.100.100.2", "fd7a:115c:a1e0::2"]},
    "b": {"Online": false, "TailscaleIPs": ["100.100.100.3"]},
    "c": {"Online": true}
  }
}''';
      expect(parseTailscalePeerIps(json), ['100.100.100.2']);
    });

    test('tolerates invalid or unexpected output', () {
      expect(parseTailscalePeerIps('not json'), isEmpty);
      expect(parseTailscalePeerIps('[]'), isEmpty);
      expect(parseTailscalePeerIps('{"Peer": null}'), isEmpty);
    });
  });
}
