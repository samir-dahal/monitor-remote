/// Where a PC running BenQ Bridge lives and the token that unlocks it.
class PairingLink {
  const PairingLink({required this.baseUrl, required this.token});

  /// The port BenQ Bridge uses unless it was started with `--port`.
  static const defaultPort = 5080;

  /// `http://host:port`, with no path.
  final Uri baseUrl;
  final String token;

  String get host => baseUrl.host;

  String get address => '${baseUrl.host}:${baseUrl.port}';

  /// Reads the link in the pairing QR code: `http://192.168.2.220:5080/#t=<token>`.
  /// Returns null for anything else, so a stray QR code is ignored rather than crashing.
  static PairingLink? tryParseQr(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return null;
    }

    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;

    Map<String, String> parts;
    try {
      parts = Uri.splitQueryString(fragment);
    } on FormatException {
      return null;
    }

    final token = parts['t']?.trim();
    if (token == null || token.isEmpty) return null;

    return PairingLink(baseUrl: _origin(uri.scheme, uri.host, uri.hasPort ? uri.port : null), token: token);
  }

  /// Builds a link from what a person types: an address like `192.168.2.220` or
  /// `192.168.2.220:5080` (with or without `http://`) and the token from the PC.
  static PairingLink? fromManualEntry(String address, String token) {
    final trimmedToken = token.trim();
    var trimmedAddress = address.trim();
    if (trimmedToken.isEmpty || trimmedAddress.isEmpty) return null;

    if (!trimmedAddress.contains('://')) trimmedAddress = 'http://$trimmedAddress';

    final uri = Uri.tryParse(trimmedAddress);
    if (uri == null || uri.host.isEmpty || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;

    return PairingLink(baseUrl: _origin(uri.scheme, uri.host, uri.hasPort ? uri.port : null), token: trimmedToken);
  }

  static Uri _origin(String scheme, String host, int? port) =>
      Uri(scheme: scheme, host: host, port: port ?? defaultPort);

  @override
  bool operator ==(Object other) =>
      other is PairingLink && other.baseUrl == baseUrl && other.token == token;

  @override
  int get hashCode => Object.hash(baseUrl, token);
}
