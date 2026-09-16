import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fast_rider/api/ride_api_client.dart';
import 'package:fast_rider/models/ride.dart';

const _request = RideRequest(
  riderId: 'rider-1',
  pickupLatitude: -23.55,
  pickupLongitude: -46.63,
  destinationLatitude: -23.56,
  destinationLongitude: -46.65,
);

void main() {
  test('creates a ride from a 201 response', () async {
    late http.BaseRequest capturedRequest;
    final client = HttpRideApiClient(
      baseUrl: 'http://localhost:8080/',
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'id': 'ride-1',
            'rider_id': 'rider-1',
            'pickup_latitude': -23.55,
            'pickup_longitude': -46.63,
            'destination_latitude': -23.56,
            'destination_longitude': -46.65,
          }),
          201,
        );
      }),
    );

    final response = await client.createRide(_request);

    expect(
      capturedRequest.url.toString(),
      'http://localhost:8080/api/v1/rides',
    );
    expect(capturedRequest.headers['content-type'], 'application/json');
    expect(capturedRequest.headers['rider_id'], 'rider-1');
    expect(capturedRequest.method, 'POST');
    expect(
      jsonDecode((capturedRequest as http.Request).body),
      _request.toJson(),
    );
    expect(response.id, 'ride-1');
  });

  test(
    'preserves code, message, requestId, and status for HTTP errors',
    () async {
      final client = HttpRideApiClient(
        baseUrl: 'http://localhost:8080',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'invalid_coordinates',
                'message': 'Coordinates are not serviceable.',
                'requestId': 'req-123',
              },
            }),
            422,
          ),
        ),
      );

      await expectLater(
        client.createRide(_request),
        throwsA(
          isA<RideApiException>()
              .having((error) => error.code, 'code', 'invalid_coordinates')
              .having(
                (error) => error.message,
                'message',
                'Coordinates are not serviceable.',
              )
              .having((error) => error.requestId, 'requestId', 'req-123')
              .having((error) => error.statusCode, 'status', 422),
        ),
      );
    },
  );

  test('turns client exceptions into connection errors', () async {
    final client = HttpRideApiClient(
      baseUrl: 'http://localhost:8080',
      client: MockClient((_) async => throw const SocketException('offline')),
    );

    await expectLater(
      client.createRide(_request),
      throwsA(
        isA<RideApiException>().having(
          (error) => error.code,
          'code',
          'connection_error',
        ),
      ),
    );
  });

  test('turns a slow request into a timeout error', () async {
    final client = HttpRideApiClient(
      baseUrl: 'http://localhost:8080',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );

    await expectLater(
      client.createRide(_request),
      throwsA(
        isA<RideApiException>().having(
          (error) => error.code,
          'code',
          'timeout',
        ),
      ),
    );
  });
}
