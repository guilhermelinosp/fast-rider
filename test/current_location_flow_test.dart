import 'dart:async';

import 'package:fast_rider/location/current_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'address_flow_test.dart';
import 'location_fake.dart';

LocationFix fix({LatLng point = originPoint, double accuracy = 10}) =>
    LocationFix(
      point: point,
      accuracyMeters: accuracy,
      timestamp: DateTime.now(),
    );

void main() {
  testWidgets('automatic GPS is the map origin and Enter completes the route', (
    tester,
  ) async {
    final gps = FakeLocation()..respond = () async => fix();
    final geocoder = FakeGeocoder();
    final router = FakeRouter();
    final api = FakeRides();
    await mount(tester, geocoder, router, api, location: gps);

    expect(gps.calls, 1);
    expect(rideMap(tester).pickup, originPoint);
    expect(find.text('A'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('address-0')), findsNothing);
    expect(find.byKey(const ValueKey('search-0')), findsNothing);
    expect(find.byKey(const ValueKey('use-location')), findsNothing);

    await submitDestination(tester, destination.label);
    expect(geocoder.queries, [destination.label]);
    expect(router.requests, [(originPoint, destinationPoint)]);
    expect(rideMap(tester).route, isNotNull);
    expect(api.requests, isEmpty);
  });

  for (final reason in [
    LocationFailure.denied,
    LocationFailure.deniedForever,
    LocationFailure.serviceDisabled,
    LocationFailure.inaccurate,
    LocationFailure.stale,
    LocationFailure.timeout,
    LocationFailure.unavailable,
  ]) {
    testWidgets('$reason: Search retries GPS automatically and then routes', (
      tester,
    ) async {
      final gps = FakeLocation()
        ..respond = () async => throw CurrentLocationException(reason);
      final geocoder = FakeGeocoder();
      final router = FakeRouter();
      final api = FakeRides();
      await mount(tester, geocoder, router, api, location: gps);

      expect(
        destinationDecoration(tester).errorText,
        CurrentLocationException(reason).message,
      );
      expect(rideMap(tester).pickup, isNull);
      expect(find.byKey(const Key('osm_attribution')), findsOneWidget);
      expect(
        find.byType(TextButton),
        findsNothing,
        reason: 'The mandatory map attribution is plain text',
      );

      gps.respond = () async => fix();
      await submitDestination(tester, destination.label);

      expect(gps.calls, 2);
      expect(rideMap(tester).pickup, originPoint);
      expect(rideMap(tester).destination, destinationPoint);
      expect(router.requests, [(originPoint, destinationPoint)]);
      expect(destinationDecoration(tester).errorText, isNull);
      expect(api.requests, isEmpty);
    });
  }

  testWidgets(
    'destination waits for an in-flight GPS fix and routes afterward',
    (tester) async {
      final pending = Completer<LocationFix>();
      final gps = FakeLocation()..respond = () => pending.future;
      final router = FakeRouter();
      await mount(
        tester,
        FakeGeocoder(),
        router,
        FakeRides(),
        location: gps,
        settle: false,
      );

      expect(destinationDecoration(tester).helperText, contains('localização'));
      await submitDestination(tester, destination.label, settle: false);
      expect(rideMap(tester).destination, destinationPoint);
      expect(router.requests, isEmpty);
      expect(
        gps.calls,
        1,
        reason: 'Search must share the in-flight GPS attempt',
      );

      pending.complete(fix());
      await tester.pumpAndSettle();
      expect(router.requests, [(originPoint, destinationPoint)]);
      expect(rideMap(tester).route, isNotNull);
    },
  );

  testWidgets('timed-out GPS is retried by the next keyboard Search', (
    tester,
  ) async {
    final first = Completer<LocationFix>();
    final gps = FakeLocation()..respond = () => first.future;
    final router = FakeRouter();
    await mount(
      tester,
      FakeGeocoder(),
      router,
      FakeRides(),
      location: gps,
      settle: false,
    );
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(
      destinationDecoration(tester).errorText,
      const CurrentLocationException(LocationFailure.timeout).message,
    );
    expect(gps.attempts.first.cancelled, isTrue);

    gps.respond = () async => fix();
    await submitDestination(tester, destination.label);
    expect(gps.calls, 2);
    expect(router.requests, [(originPoint, destinationPoint)]);

    first.complete(fix(point: const LatLng(-10, -10)));
    await tester.pumpAndSettle();
    expect(rideMap(tester).pickup, originPoint);
  });

  testWidgets('automatic retry rejects poor accuracy without another control', (
    tester,
  ) async {
    final gps = FakeLocation()
      ..respond = () async =>
          throw const CurrentLocationException(LocationFailure.denied);
    await mount(
      tester,
      FakeGeocoder(),
      FakeRouter(),
      FakeRides(),
      location: gps,
    );

    gps.respond = () async => fix(accuracy: 300);
    await submitDestination(tester, destination.label);

    expect(
      destinationDecoration(tester).errorText,
      const CurrentLocationException(LocationFailure.inaccurate).message,
    );
    expect(rideMap(tester).pickup, isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('use-location')), findsNothing);
  });

  testWidgets('background cancellation stays stale after a Search retry', (
    tester,
  ) async {
    final first = Completer<LocationFix>();
    final gps = FakeLocation()..respond = () => first.future;
    final router = FakeRouter();
    await mount(
      tester,
      FakeGeocoder(),
      router,
      FakeRides(),
      location: gps,
      settle: false,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(gps.attempts.single.cancelled, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(gps.attempts.single.cancelled, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    gps.respond = () async => fix();
    await submitDestination(tester, destination.label);
    first.complete(fix(point: const LatLng(-10, -10)));
    await tester.pumpAndSettle();

    expect(gps.calls, 2);
    expect(rideMap(tester).pickup, originPoint);
    expect(router.requests, [(originPoint, destinationPoint)]);
    expect(tester.takeException(), isNull);
  });

  for (final error in [false, true]) {
    testWidgets('dispose consumes late GPS ${error ? 'error' : 'success'}', (
      tester,
    ) async {
      final pending = Completer<LocationFix>();
      final gps = FakeLocation()..respond = () => pending.future;
      await mount(
        tester,
        FakeGeocoder(),
        FakeRouter(),
        FakeRides(),
        location: gps,
        settle: false,
      );
      await tester.pumpWidget(const SizedBox());
      expect(gps.attempts.single.cancelled, isTrue);
      if (error) {
        pending.completeError(StateError('late'));
      } else {
        pending.complete(fix());
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
