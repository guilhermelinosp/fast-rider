import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:fast_rider/api/location_services.dart';
import 'package:fast_rider/widgets/ride_map.dart';

import 'address_contract_test.dart' show OfflineTiles;

const _pickup = LatLng(-23.550520, -46.633308);
const _destination = LatLng(-23.561684, -46.655981);
const _midpoint = LatLng(-23.555000, -46.640000);
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _tilePackage = 'com.guilhermelino.fastrider';

RideMap _map({
  LatLng? pickup,
  LatLng? destination,
  RoadRoute? route,
  TileProvider? tileProvider,
}) => RideMap(
  tileUrl: _tileUrl,
  tileUserAgentPackageName: _tilePackage,
  pickup: pickup,
  destination: destination,
  route: route,
  tileProvider: tileProvider,
);

RoadRoute _route({bool includeMidpoint = true}) => RoadRoute(
  points: [_pickup, if (includeMidpoint) _midpoint, _destination],
  distanceMeters: 3200,
  durationSeconds: 480,
);

Future<void> _mount(WidgetTester tester, RideMap map) async {
  await tester.binding.setSurfaceSize(const Size(430, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox(height: 500, child: map)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty map has no markers and no route polyline', (tester) async {
    await _mount(tester, _map(tileProvider: OfflineTiles()));
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isEmpty,
    );
    expect(find.byType(PolylineLayer), findsNothing);
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('renders A/B markers and the road route polyline', (
    tester,
  ) async {
    await _mount(
      tester,
      _map(
        pickup: _pickup,
        destination: _destination,
        route: _route(),
        tileProvider: OfflineTiles(),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(layer.polylines, hasLength(1));
    expect(layer.polylines.single.points, [_pickup, _midpoint, _destination]);
  });

  testWidgets('map is display only: no interaction flags and no tap handler', (
    tester,
  ) async {
    await _mount(tester, _map(tileProvider: OfflineTiles()));
    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    expect(options.interactionOptions.flags, InteractiveFlag.none);
    expect(options.onTap, isNull);
    expect(options.onLongPress, isNull);
  });

  testWidgets('attribution is visible compact plain text and not clickable', (
    tester,
  ) async {
    await _mount(tester, _map(tileProvider: OfflineTiles()));

    final attribution = find.byKey(const Key('osm_attribution'));
    final surface = find.byKey(const Key('osm_attribution_surface'));
    expect(attribution, findsOneWidget);
    expect(find.text('© OpenStreetMap contributors · ODbL'), findsOneWidget);

    final label = tester.widget<Text>(attribution);
    expect(label.data, '© OpenStreetMap contributors · ODbL');
    expect(label.style?.fontSize, 10);
    expect(label.style?.color, Colors.white.withValues(alpha: 0.85));

    final background = tester.widget<Material>(surface);
    expect(background.color, Colors.black.withValues(alpha: 0.55));
    expect(background.borderRadius, BorderRadius.circular(4));
    expect(
      find.descendant(
        of: surface,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding ==
                  const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        ),
      ),
      findsOneWidget,
    );
    for (final interactiveType in [TextButton, InkWell, GestureDetector]) {
      expect(
        find.descendant(of: surface, matching: find.byType(interactiveType)),
        findsNothing,
      );
    }

    await tester.tap(attribution);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Licença:'), findsNothing);
  });

  testWidgets('tile errors show a single notice and keep markers visible', (
    tester,
  ) async {
    await _mount(
      tester,
      _map(
        pickup: _pickup,
        destination: _destination,
        route: _route(),
        tileProvider: OfflineTiles(),
      ),
    );

    final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
    final tile = TileImage(
      vsync: tester,
      coordinates: const TileCoordinates(0, 0, 0),
      imageProvider: MemoryImage(TileProvider.transparentImage),
      onLoadComplete: (_) {},
      onLoadError: (_, _, _) {},
      tileDisplay: const TileDisplay.instantaneous(),
      errorImage: null,
      cancelLoading: Completer<void>(),
    );
    addTearDown(tile.dispose);
    expect(tester.binding.hasScheduledFrame, isFalse);
    tileLayer.errorTileCallback!(tile, Object(), StackTrace.current);
    // pumpAndSettle schedules its first frame even when the app is idle;
    // verify that the callback itself wakes the map before pumping.
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível carregar parte do mapa'),
      findsOneWidget,
    );
    tileLayer.errorTileCallback!(tile, Object(), null);
    await tester.pump();

    expect(
      find.textContaining('Não foi possível carregar parte do mapa'),
      findsOneWidget,
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byKey(const Key('osm_attribution')), findsOneWidget);
  });

  testWidgets('refitting the camera with route updates does not throw', (
    tester,
  ) async {
    await _mount(
      tester,
      _map(
        pickup: _pickup,
        destination: _destination,
        route: _route(),
        tileProvider: OfflineTiles(),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: _map(
              pickup: _destination,
              destination: _pickup,
              route: _route(includeMidpoint: false),
              tileProvider: OfflineTiles(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a supplied GPS origin is the initial map center', (
    tester,
  ) async {
    await _mount(tester, _map(pickup: _pickup, tileProvider: OfflineTiles()));
    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    expect(options.initialCenter, _pickup);
    expect(find.text('A'), findsOneWidget);
  });
}
