import 'dart:async';

import 'package:fast_rider/location/current_location.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

const _channel = MethodChannel('fast_rider/current_position');
const _settings = LocationSettings(
  accuracy: LocationAccuracy.high,
  timeLimit: Duration(seconds: 7),
);

Matcher _failure(LocationFailure reason) => isA<CurrentLocationException>()
    .having((error) => error.reason, 'reason', reason);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test(
    'uses the exact channel contract and decodes a successful fix',
    () async {
      MethodCall? captured;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        captured = call;
        return <String, Object>{
          'latitude': -23.55,
          'longitude': -46.63,
          'accuracy': 8.5,
          'has_accuracy': true,
          'timestamp': 1789550400000,
        };
      });

      final result = await IosSinglePosition().read(
        LocationAttempt(),
        _settings,
      );

      expect(captured?.method, 'capture');
      final arguments = captured?.arguments as Map<Object?, Object?>;
      expect(arguments['id'], isA<String>());
      expect(arguments['timeoutMs'], 7000);
      expect(result.latitude, -23.55);
      expect(result.longitude, -46.63);
      expect(result.accuracy, 8.5);
      expect(result.hasAccuracy, isTrue);
      expect(
        result.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1789550400000, isUtc: true),
      );
    },
  );

  test('maps structured native errors to domain failures', () async {
    for (final entry in <(String, LocationFailure)>[
      ('timeout', LocationFailure.timeout),
      ('cancelled', LocationFailure.cancelled),
      ('denied', LocationFailure.denied),
      ('serviceDisabled', LocationFailure.serviceDisabled),
      ('native_error', LocationFailure.unavailable),
    ]) {
      messenger.setMockMethodCallHandler(
        _channel,
        (_) async => throw PlatformException(
          code: entry.$1,
          message: 'native failure',
          details: const {'source': 'CoreLocation'},
        ),
      );

      await expectLater(
        IosSinglePosition().read(LocationAttempt(), _settings),
        throwsA(_failure(entry.$2)),
      );
    }
  });

  test(
    'cancelling an attempt sends cancel with the active capture id',
    () async {
      final captureStarted = Completer<MethodCall>();
      final captureResult = Completer<Object?>();
      MethodCall? cancelCall;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'capture') {
          captureStarted.complete(call);
          return captureResult.future;
        }
        if (call.method == 'cancel') {
          cancelCall = call;
          captureResult.completeError(
            PlatformException(code: 'cancelled', message: 'cancelled by Dart'),
          );
          return null;
        }
        throw PlatformException(code: 'unexpected');
      });

      final attempt = LocationAttempt();
      final read = IosSinglePosition().read(attempt, _settings);
      final captureCall = await captureStarted.future;
      final expectation = expectLater(
        read,
        throwsA(_failure(LocationFailure.cancelled)),
      );

      attempt.cancel();
      await expectation;
      await Future<void>.delayed(Duration.zero);

      expect(cancelCall?.method, 'cancel');
      expect(
        (cancelCall?.arguments as Map<Object?, Object?>)['id'],
        (captureCall.arguments as Map<Object?, Object?>)['id'],
      );
    },
  );

  test(
    'missing plugin and unexpected platform failures are unavailable',
    () async {
      await expectLater(
        IosSinglePosition().read(LocationAttempt(), _settings),
        throwsA(_failure(LocationFailure.unavailable)),
      );

      messenger.setMockMethodCallHandler(
        _channel,
        (_) async => throw StateError('broken platform bridge'),
      );
      await expectLater(
        IosSinglePosition().read(LocationAttempt(), _settings),
        throwsA(_failure(LocationFailure.unavailable)),
      );
    },
  );
}
