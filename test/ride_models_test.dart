import 'package:flutter_test/flutter_test.dart';

import 'package:fast_rider/models/ride.dart';

void main() {
  test('serializes ride coordinates with the backend snake_case contract', () {
    const request = RideRequest(
      riderId: 'rider-1',
      pickupLatitude: -23.55,
      pickupLongitude: -46.63,
      destinationLatitude: -23.56,
      destinationLongitude: -46.65,
    );

    expect(request.toJson(), {
      'pickup_latitude': -23.55,
      'pickup_longitude': -46.63,
      'destination_latitude': -23.56,
      'destination_longitude': -46.65,
    });
  });

  test('parses the create ride response', () {
    final response = RideResponse.fromJson({
      'id': 'ride-1',
      'rider_id': 'rider-1',
      'pickup_latitude': -23.55,
      'pickup_longitude': -46.63,
      'destination_latitude': -23.56,
      'destination_longitude': -46.65,
    });

    expect(response.id, 'ride-1');
    expect(response.destinationLongitude, -46.65);
  });
}
