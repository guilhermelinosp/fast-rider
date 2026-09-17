import 'package:fast_rider/api/location_services.dart';
import 'package:fast_rider/config/app_config.dart';
import 'package:fast_rider/location/current_location.dart';
import 'package:fast_rider/main.dart';
import 'package:fast_rider/pages/ride_page.dart';
import 'package:fast_rider/widgets/ride_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _GeocoderFake implements Geocoder {
  @override
  Future<List<AddressPlace>> search(String query) async => const [];
}

class _RouterFake implements RoadRouter {
  @override
  Future<RoadRoute> route(LatLng pickup, LatLng destination) =>
      throw StateError('No route is requested during startup');
}

class _LocationFake implements CurrentLocation {
  @override
  Future<LocationFix> locate(LocationAttempt attempt) async => LocationFix(
    point: const LatLng(-23.550520, -46.633308),
    accuracyMeters: 10,
    timestamp: DateTime.now(),
  );
}

class _OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

void main() {
  testWidgets('RiderApp starts with AppConfig defaults and no dart-defines', (
    tester,
  ) async {
    const config = AppConfig();
    expect(config.validate, returnsNormally);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RiderApp(
        config: config,
        geocoder: _GeocoderFake(),
        router: _RouterFake(),
        tileProvider: _OfflineTiles(),
        currentLocation: _LocationFake(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(RidePage), findsOneWidget);
    expect(find.byType(RideMap), findsOneWidget);
    expect(find.byKey(const ValueKey('address-1')), findsOneWidget);
    expect(find.byKey(const Key('osm_attribution')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tile configuration reaches FlutterMap without a hardcoded URL', (
    tester,
  ) async {
    const config = AppConfig(
      tileUrl: 'https://tiles.example/{z}/{x}/{y}.png',
      tileUserAgentPackageName: 'com.guilhermelino.fastrider.test',
    );
    final tiles = _OfflineTiles();

    await tester.pumpWidget(
      RiderApp(
        config: config,
        geocoder: _GeocoderFake(),
        router: _RouterFake(),
        tileProvider: tiles,
        currentLocation: _LocationFake(),
      ),
    );
    await tester.pumpAndSettle();

    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.urlTemplate, config.tileUrl);
    expect(
      layer.tileProvider.headers['User-Agent'],
      'flutter_map (${config.tileUserAgentPackageName})',
    );
  });
}
