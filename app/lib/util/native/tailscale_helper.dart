import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final _logger = Logger('Tailscale');

/// Whether [ip] lies in the CGNAT range `100.64.0.0/10`, which Tailscale assigns to its devices.
/// Multicast and subnet scans do not work there, so such addresses are probed individually instead.
bool isTailscaleAddress(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) {
    return false;
  }
  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  return first == 100 && second != null && second >= 64 && second <= 127;
}

/// Extracts the IPv4 addresses of all online peers from the output of `tailscale status --json`.
List<String> parseTailscalePeerIps(String json) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    return const [];
  }

  final peers = decoded is Map<String, dynamic> ? decoded['Peer'] : null;
  if (peers is! Map<String, dynamic>) {
    return const [];
  }

  final result = <String>[];
  for (final peer in peers.values) {
    if (peer is! Map<String, dynamic> || peer['Online'] != true) {
      continue;
    }
    final ips = peer['TailscaleIPs'];
    if (ips is! List) {
      continue;
    }
    for (final ip in ips) {
      if (ip is String && isTailscaleAddress(ip)) {
        result.add(ip);
      }
    }
  }
  return result;
}

/// Asks the local Tailscale client for the online peers of the tailnet.
/// Only desktop platforms can do this (needs the `tailscale` CLI); elsewhere,
/// and when Tailscale is not installed or not running, the result is empty.
Future<List<String>> fetchTailscalePeerIps() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return const [];
  }

  final executables = [
    'tailscale',
    if (Platform.isWindows) r'C:\Program Files\Tailscale\tailscale.exe',
  ];

  for (final executable in executables) {
    try {
      final result = await Process.run(executable, ['status', '--json']).timeout(const Duration(seconds: 3));
      if (result.exitCode == 0) {
        return parseTailscalePeerIps(result.stdout.toString());
      }
    } catch (e) {
      _logger.fine('Cannot run $executable', e);
    }
  }
  return const [];
}
