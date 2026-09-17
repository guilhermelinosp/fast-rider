/// Runtime configuration backed by optional compile-time overrides.
///
/// The public provider defaults are non-secret, so a normal `flutter run` or
/// build starts without a `.env` file. Deployments can still replace them with
/// `--dart-define` or `--dart-define-from-file`.
final class AppConfig {
  const AppConfig({
    this.geocodingUrl = const String.fromEnvironment(
      'GEOCODING_URL',
      defaultValue: 'https://nominatim.openstreetmap.org/search',
    ),
    this.routingUrl = const String.fromEnvironment(
      'ROUTING_URL',
      defaultValue: 'https://router.project-osrm.org',
    ),
    this.tileUrl = const String.fromEnvironment(
      'MAP_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    this.mapsUserAgent = const String.fromEnvironment(
      'MAPS_USER_AGENT',
      defaultValue: 'com.guilhermelino.fastrider/1.0.0',
    ),
    this.tileUserAgentPackageName = 'com.guilhermelino.fastrider',
  });

  final String geocodingUrl;
  final String routingUrl;
  final String tileUrl;
  final String mapsUserAgent;

  /// Package identifier used by flutter_map to form its tile User-Agent.
  final String tileUserAgentPackageName;

  /// Fails early only for malformed overrides, never for omitted defines.
  void validate() {
    _validateHttpUrl('GEOCODING_URL', geocodingUrl);
    _validateHttpUrl('ROUTING_URL', routingUrl);
    _validateHttpUrl('MAP_TILE_URL', tileUrl);

    const placeholders = ['{z}', '{x}', '{y}'];
    if (!placeholders.every(tileUrl.contains)) {
      throw StateError(
        'AppConfig: MAP_TILE_URL must contain {z}, {x}, and {y}.',
      );
    }

    _validateHeaderValue('MAPS_USER_AGENT', mapsUserAgent);
    if (!_packageName.hasMatch(tileUserAgentPackageName)) {
      throw StateError(
        'AppConfig: tile User-Agent package must be a reverse-DNS identifier.',
      );
    }
  }

  static final RegExp _headerControlCharacters = RegExp(
    r'[\u0000-\u001F\u007F]',
  );
  static final RegExp _packageName = RegExp(
    r'^[A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)+$',
  );

  static void _validateHttpUrl(String name, String value) {
    final uri = Uri.tryParse(value);
    if (value != value.trim() ||
        uri == null ||
        !const {'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw StateError(
        'AppConfig: $name must be an absolute HTTP(S) URL without credentials or fragments.',
      );
    }
  }

  static void _validateHeaderValue(String name, String value) {
    if (value != value.trim() ||
        value.isEmpty ||
        value.length > 256 ||
        _headerControlCharacters.hasMatch(value)) {
      throw StateError(
        'AppConfig: $name must be a non-empty HTTP header value.',
      );
    }
  }
}
