import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';
import 'pairing_link.dart';

/// Something went wrong talking to the PC. [message] is safe to show to the user.
class BridgeException implements Exception {
  const BridgeException(this.message, {this.unauthorized = false});

  final String message;

  /// The PC rejected the token, so retrying will not help; the phone has to pair again.
  final bool unauthorized;

  @override
  String toString() => message;
}

/// The BenQ Bridge HTTP and WebSocket API, as the app uses it.
abstract class BridgeApi {
  Future<List<Monitor>> monitors();

  Future<void> writeVcp(String monitorId, int code, int value);

  Future<void> refresh(String monitorId);

  /// Pushes the full monitor list whenever anything changes on the PC. The stream ends when
  /// the connection drops; the caller decides when to reconnect.
  Stream<List<Monitor>> watch();

  void close();
}

typedef BridgeApiFactory = BridgeApi Function(PairingLink link);

class HttpBridgeApi implements BridgeApi {
  HttpBridgeApi(this.link, {http.Client? client, this.timeout = const Duration(seconds: 6)})
    : _client = client ?? http.Client();

  final PairingLink link;
  final Duration timeout;
  final http.Client _client;

  Map<String, String> get _headers => {'X-Api-Token': link.token};

  Uri _uri(String path) => link.baseUrl.replace(path: path);

  @override
  Future<List<Monitor>> monitors() async {
    final response = await _send(() => _client.get(_uri('/api/monitors'), headers: _headers));
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return [for (final item in decoded) Monitor.fromJson(item as Map<String, dynamic>)];
  }

  @override
  Future<void> writeVcp(String monitorId, int code, int value) async {
    final hex = code.toRadixString(16).toUpperCase().padLeft(2, '0');
    await _send(
      () => _client.put(
        _uri('/api/monitors/${Uri.encodeComponent(monitorId)}/vcp/$hex'),
        headers: {..._headers, 'Content-Type': 'application/json'},
        body: jsonEncode({'value': value}),
      ),
    );
  }

  @override
  Future<void> refresh(String monitorId) async {
    await _send(() => _client.post(_uri('/api/monitors/${Uri.encodeComponent(monitorId)}/refresh'), headers: _headers));
  }

  @override
  Stream<List<Monitor>> watch() async* {
    final channel = WebSocketChannel.connect(
      Uri(
        scheme: link.baseUrl.scheme == 'https' ? 'wss' : 'ws',
        host: link.baseUrl.host,
        port: link.baseUrl.port,
        path: '/ws',
        queryParameters: {'token': link.token},
      ),
    );

    try {
      await channel.ready.timeout(timeout);
      await for (final message in channel.stream) {
        final decoded = jsonDecode(message as String);
        if (decoded is Map<String, dynamic> && decoded['type'] == 'state') {
          yield [
            for (final item in (decoded['monitors'] as List<dynamic>? ?? const []))
              Monitor.fromJson(item as Map<String, dynamic>),
          ];
        }
      }
    } on TimeoutException {
      throw const BridgeException("Couldn't reach your PC.");
    } finally {
      await channel.sink.close();
    }
  }

  @override
  void close() => _client.close();

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const BridgeException("Your PC didn't answer. Check that BenQ Bridge is running.");
    } on http.ClientException {
      throw const BridgeException("Couldn't reach your PC. Check that you're on the same Wi-Fi.");
    } on FormatException {
      throw const BridgeException("That address doesn't look right.");
    } catch (_) {
      throw const BridgeException("Couldn't reach your PC. Check that you're on the same Wi-Fi.");
    }

    if (response.statusCode == 401) {
      throw const BridgeException('That token was rejected. Pair again.', unauthorized: true);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BridgeException(_errorFrom(response) ?? 'Your PC returned an error (${response.statusCode}).');
    }

    return response;
  }

  static String? _errorFrom(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded['error'] as String? ?? decoded['title'] as String?;
    } catch (_) {
      // not JSON: fall through
    }
    return null;
  }
}
