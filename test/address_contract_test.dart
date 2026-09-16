import 'package:fast_rider/api/ride_api_client.dart';
import 'package:fast_rider/models/ride.dart';
import 'package:fast_rider/pages/ride_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'location_fake.dart';

class OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class NoRides implements RideApiClient {
  @override
  Future<RideResponse> createRide(RideRequest request) =>
      throw StateError('No ride should be submitted');
}

void main() {
  testWidgets(
    'destination is the only editable input; origin is never manual',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RidePage(
            apiClient: NoRides(),
            riderId: 'rider',
            tileProvider: OfflineTiles(),
            currentLocation: FakeLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const ValueKey('address-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('address-0')), findsNothing);
    },
  );

  testWidgets('map is display only with every gesture disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RidePage(
          apiClient: NoRides(),
          riderId: 'rider',
          tileProvider: OfflineTiles(),
          currentLocation: FakeLocation(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final options = tester.widget<FlutterMap>(find.byType(FlutterMap)).options;
    expect(options.interactionOptions.flags, InteractiveFlag.none);
    expect(options.onTap, isNull);
  });
}
