class AppConfig {
  AppConfig._();

  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const geocodingUrl = String.fromEnvironment(
    'GEOCODING_URL',
    defaultValue: 'https://nominatim.openstreetmap.org/search',
  );
  static const routingUrl = String.fromEnvironment(
    'ROUTING_URL',
    defaultValue: 'https://router.project-osrm.org',
  );
  static const mapsUserAgent = String.fromEnvironment(
    'MAPS_USER_AGENT',
    defaultValue: 'fast_rider/1.0 (development address-route preview)',
  );
  static const geocodingAttribution = String.fromEnvironment(
    'GEOCODING_ATTRIBUTION',
    defaultValue: 'Busca: Nominatim',
  );
  static const routingAttribution = String.fromEnvironment(
    'ROUTING_ATTRIBUTION',
    defaultValue: 'Rota: OSRM',
  );

  static String get baseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : 'http://localhost:8080';
}
