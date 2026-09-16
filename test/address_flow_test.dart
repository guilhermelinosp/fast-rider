import 'dart:async';

import 'package:fast_rider/api/location_services.dart';
import 'package:fast_rider/api/ride_api_client.dart';
import 'package:fast_rider/location/current_location.dart';
import 'package:fast_rider/models/ride.dart';
import 'package:fast_rider/pages/ride_page.dart';
import 'package:fast_rider/ride_theme.dart';
import 'package:fast_rider/widgets/ride_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'address_contract_test.dart' show OfflineTiles;
import 'location_fake.dart';

const originPoint = LatLng(-23.55, -46.63);
const destinationPoint = LatLng(-23.56, -46.65);
const origin = AddressPlace(label: 'Sé, São Paulo', point: originPoint);
const destination = AddressPlace(
  label: 'Paulista, São Paulo',
  point: destinationPoint,
);

LocationFix gpsFix({LatLng point = originPoint, double accuracy = 10}) =>
    LocationFix(
      point: point,
      accuracyMeters: accuracy,
      timestamp: DateTime.now(),
    );

FakeLocation successfulGps({LatLng point = originPoint}) =>
    FakeLocation()..respond = () async => gpsFix(point: point);

RoadRoute road({LatLng destination = destinationPoint}) => RoadRoute(
  points: [originPoint, const LatLng(-23.57, -46.64), destination],
  distanceMeters: 3200,
  durationSeconds: 600,
);

class FakeGeocoder implements Geocoder {
  final queries = <String>[];
  Future<List<AddressPlace>> Function(String)? respond;

  @override
  Future<List<AddressPlace>> search(String query) {
    queries.add(query);
    return respond?.call(query) ?? Future.value([destination, origin]);
  }
}

class FakeRouter implements RoadRouter {
  final requests = <(LatLng, LatLng)>[];
  Future<RoadRoute> Function(LatLng, LatLng)? respond;

  @override
  Future<RoadRoute> route(LatLng origin, LatLng destination) {
    requests.add((origin, destination));
    return respond?.call(origin, destination) ??
        Future.value(road(destination: destination));
  }
}

class FakeRides implements RideApiClient {
  final requests = <RideRequest>[];

  @override
  Future<RideResponse> createRide(RideRequest request) {
    requests.add(request);
    throw StateError('RidePage must not create rides');
  }
}

Future<void> mount(
  WidgetTester tester,
  FakeGeocoder geocoder,
  FakeRouter router,
  FakeRides api, {
  Size size = const Size(390, 844),
  double textScale = 1,
  FakeLocation? location,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: RideTheme.data,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: RidePage(
        apiClient: api,
        riderId: 'uuid-test',
        geocoder: geocoder,
        router: router,
        tileProvider: OfflineTiles(),
        currentLocation: location ?? successfulGps(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> typeDestination(WidgetTester tester, String text) async {
  final field = find.byKey(const ValueKey('address-1'));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> submitDestination(
  WidgetTester tester,
  String text, {
  bool settle = true,
}) async {
  await typeDestination(tester, text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

RideMap rideMap(WidgetTester tester) =>
    tester.widget<RideMap>(find.byType(RideMap));

InputDecoration destinationDecoration(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey('address-1')))
    .decoration!;

void main() {
  testWidgets(
    'Search action geocodes once, picks the first result and draws GPS route',
    (tester) async {
      final geocoder = FakeGeocoder();
      final router = FakeRouter();
      final api = FakeRides();
      await mount(tester, geocoder, router, api);

      await submitDestination(tester, 'Avenida Paulista');

      expect(geocoder.queries, ['Avenida Paulista']);
      expect(router.requests, [(originPoint, destinationPoint)]);
      expect(rideMap(tester).pickup, originPoint);
      expect(rideMap(tester).destination, destinationPoint);
      expect(rideMap(tester).route?.points, road().points);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(api.requests, isEmpty);
    },
  );

  testWidgets('typing alone does nothing and repeated Search is deduplicated', (
    tester,
  ) async {
    final pending = Completer<List<AddressPlace>>();
    final geocoder = FakeGeocoder()..respond = (_) => pending.future;
    final router = FakeRouter();
    final api = FakeRides();
    await mount(tester, geocoder, router, api);

    await typeDestination(tester, 'Paulista');
    expect(geocoder.queries, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(geocoder.queries, ['Paulista']);
    expect(destinationDecoration(tester).suffixIcon, isNotNull);

    pending.complete([destination, origin]);
    await tester.pumpAndSettle();
    expect(router.requests, hasLength(1));
    expect(api.requests, isEmpty);
  });

  testWidgets('the first valid result is selected automatically', (
    tester,
  ) async {
    const invalid = AddressPlace(label: 'Inválido', point: LatLng(91, -46.6));
    final geocoder = FakeGeocoder()
      ..respond = (_) async => [invalid, destination, origin];
    final router = FakeRouter();
    await mount(tester, geocoder, router, FakeRides());

    await submitDestination(tester, 'destino');

    expect(rideMap(tester).destination, destinationPoint);
    expect(router.requests, [(originPoint, destinationPoint)]);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('address-1')))
          .controller
          ?.text,
      destination.label,
    );
  });

  testWidgets('late geocoding cannot replace a newer destination', (
    tester,
  ) async {
    const newerPoint = LatLng(-23.58, -46.67);
    const newer = AddressPlace(label: 'Destino novo', point: newerPoint);
    final old = Completer<List<AddressPlace>>();
    final geocoder = FakeGeocoder()
      ..respond = (query) =>
          query == 'antigo' ? old.future : Future.value([newer]);
    final router = FakeRouter();
    await mount(tester, geocoder, router, FakeRides());

    await submitDestination(tester, 'antigo', settle: false);
    await submitDestination(tester, 'novo');
    old.complete([destination]);
    await tester.pumpAndSettle();

    expect(geocoder.queries, ['antigo', 'novo']);
    expect(rideMap(tester).destination, newerPoint);
    expect(router.requests, [(originPoint, newerPoint)]);
  });

  testWidgets('late route is discarded when the destination is edited', (
    tester,
  ) async {
    final pending = Completer<RoadRoute>();
    final router = FakeRouter()..respond = (_, _) => pending.future;
    await mount(tester, FakeGeocoder(), router, FakeRides());

    await submitDestination(tester, 'primeiro', settle: false);
    await typeDestination(tester, 'segundo');
    pending.complete(road());
    await tester.pumpAndSettle();

    expect(rideMap(tester).destination, isNull);
    expect(rideMap(tester).route, isNull);
    expect(find.byType(PolylineLayer), findsNothing);
  });

  testWidgets('geocoding and routing failures stay inside the input', (
    tester,
  ) async {
    final geocoder = FakeGeocoder()
      ..respond = (_) async =>
          throw const LocationException('offline', 'Sem conexão');
    final router = FakeRouter();
    final api = FakeRides();
    await mount(tester, geocoder, router, api);

    await submitDestination(tester, 'sem rede');
    expect(destinationDecoration(tester).errorText, 'Sem conexão');
    expect(find.byType(SnackBar), findsNothing);

    geocoder.respond = (_) async => [destination];
    router.respond = (_, _) async =>
        throw const LocationException('no_route', 'Nenhuma rota encontrada');
    await submitDestination(tester, 'Paulista');
    expect(destinationDecoration(tester).errorText, 'Nenhuma rota encontrada');
    expect(rideMap(tester).route, isNull);
    expect(api.requests, isEmpty);
  });

  testWidgets('empty and invalid result sets expose a compact field error', (
    tester,
  ) async {
    final geocoder = FakeGeocoder()..respond = (_) async => [];
    await mount(tester, geocoder, FakeRouter(), FakeRides());

    await submitDestination(tester, 'desconhecido');
    expect(
      destinationDecoration(tester).errorText,
      contains('Nenhum endereço encontrado'),
    );

    geocoder.respond = (_) async => const [
      AddressPlace(label: 'Inválido', point: LatLng(100, 200)),
    ];
    await submitDestination(tester, 'inválido');
    expect(
      destinationDecoration(tester).errorText,
      contains('coordenadas válidas'),
    );
  });

  testWidgets('destination equal to GPS origin is rejected without routing', (
    tester,
  ) async {
    final geocoder = FakeGeocoder()..respond = (_) async => [origin];
    final router = FakeRouter();
    await mount(tester, geocoder, router, FakeRides());

    await submitDestination(tester, origin.label);

    expect(router.requests, isEmpty);
    expect(
      destinationDecoration(tester).errorText,
      contains('pontos diferentes'),
    );
  });

  for (final operation in ['search', 'route']) {
    testWidgets('dispose while $operation is pending ignores late errors', (
      tester,
    ) async {
      final geocoder = FakeGeocoder();
      final router = FakeRouter();
      final search = Completer<List<AddressPlace>>();
      final route = Completer<RoadRoute>();
      if (operation == 'search') geocoder.respond = (_) => search.future;
      if (operation == 'route') router.respond = (_, _) => route.future;
      await mount(tester, geocoder, router, FakeRides());
      await submitDestination(tester, 'destino', settle: false);

      await tester.pumpWidget(const SizedBox());
      if (operation == 'search') {
        search.completeError(StateError('late'));
      } else {
        route.completeError(StateError('late'));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
