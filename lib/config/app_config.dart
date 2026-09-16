/// Compile-time configuration injected via `--dart-define-from-file`.
///
/// Every value is **required** — call [validate] at app startup to fail fast
/// with a clear message when any environment variable is missing.
///
/// Usage:
/// ```bash
/// cp .env.example .env   # fill in ALL values
/// flutter run --dart-define-from-file=.env
/// ```
class AppConfig {
  AppConfig._();

  /// Base URL for the ride backend API.
  static const String baseUrl = String.fromEnvironment('API_BASE_URL');

  /// Geocoding endpoint (Nominatim-compatible `/search`).
  static const String geocodingUrl = String.fromEnvironment('GEOCODING_URL');

  /// Routing endpoint (OSRM-compatible).
  static const String routingUrl = String.fromEnvironment('ROUTING_URL');

  /// User-Agent sent to OSM providers (required by their usage policy).
  static const String mapsUserAgent = String.fromEnvironment('MAPS_USER_AGENT');

  /// Attribution text for the geocoding provider (required by Nominatim).
  static const String geocodingAttribution = String.fromEnvironment(
    'GEOCODING_ATTRIBUTION',
  );

  /// Attribution text for the routing provider (required by OSRM).
  static const String routingAttribution = String.fromEnvironment(
    'ROUTING_ATTRIBUTION',
  );

  /// Checks that every required env var was provided.
  ///
  /// Call this **once** at the top of `main()` before using any field.
  /// Throws [StateError] with the exact command to fix the issue.
  static void validate() {
    final missing = <String>[
      if (baseUrl.isEmpty) 'API_BASE_URL',
      if (geocodingUrl.isEmpty) 'GEOCODING_URL',
      if (routingUrl.isEmpty) 'ROUTING_URL',
      if (mapsUserAgent.isEmpty) 'MAPS_USER_AGENT',
      if (geocodingAttribution.isEmpty) 'GEOCODING_ATTRIBUTION',
      if (routingAttribution.isEmpty) 'ROUTING_ATTRIBUTION',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'AppConfig: missing required env vars: ${missing.join(', ')}\n'
        'Fix: cp .env.example .env && flutter run --dart-define-from-file=.env',
      );
    }
  }
}
