import 'package:fast_rider/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are complete, public, and valid without dart-defines', () {
    const config = AppConfig();

    expect(() => config.validate(), returnsNormally);
    expect(config.geocodingUrl, 'https://nominatim.openstreetmap.org/search');
    expect(config.routingUrl, 'https://router.project-osrm.org');
    expect(config.tileUrl, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(config.mapsUserAgent, 'com.guilhermelino.fastrider/1.0.0');
    expect(config.tileUserAgentPackageName, 'com.guilhermelino.fastrider');
  });

  test('malformed provider overrides fail with their configuration key', () {
    for (final entry in <(AppConfig, String)>[
      (
        const AppConfig(geocodingUrl: 'nominatim.example/search'),
        'GEOCODING_URL',
      ),
      (
        const AppConfig(routingUrl: 'https://user@route.example'),
        'ROUTING_URL',
      ),
      (
        const AppConfig(tileUrl: 'https://tiles.example/static.png'),
        'MAP_TILE_URL',
      ),
      (const AppConfig(mapsUserAgent: 'bad\nagent'), 'MAPS_USER_AGENT'),
    ]) {
      expect(
        entry.$1.validate,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(entry.$2),
          ),
        ),
      );
    }
  });
}
