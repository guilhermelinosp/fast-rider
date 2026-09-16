import 'dart:async';

import 'package:fast_rider/location/current_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

final now = DateTime.utc(2026, 9, 15, 12);

Position position({
  double latitude = -23.55,
  double accuracy = 12,
  bool hasAccuracy = true,
  DateTime? timestamp,
}) => Position(
  latitude: latitude,
  longitude: -46.63,
  timestamp: timestamp ?? now,
  accuracy: accuracy,
  hasAccuracy: hasAccuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class PlatformFake extends GeolocatorPlatform {
  final calls = <String>[];
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission answer = LocationPermission.whileInUse;
  Future<LocationPermission> Function()? request;
  Future<Position> Function()? read;
  LocationSettings? settings;

  @override
  Future<bool> isLocationServiceEnabled() async {
    calls.add('service');
    return enabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    calls.add('check');
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    calls.add('request');
    return request == null ? answer : await request!();
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    calls.add('position');
    settings = locationSettings;
    return read == null ? position() : await read!();
  }
}

Matcher failure(LocationFailure reason) =>
    isA<CurrentLocationException>().having((e) => e.reason, 'reason', reason);

void main() {
  test(
    'granted reads once, no prompt/cache/streams, Apple background disabled',
    () async {
      final platform = PlatformFake();
      final provider = GeolocatorCurrentLocation(
        platform: platform,
        now: () => now,
      );
      final fix = await provider.locate(LocationAttempt());
      expect(fix.point.latitude, -23.55);
      expect(platform.calls, ['service', 'check', 'position']);
      expect(platform.settings!.timeLimit, const Duration(seconds: 15));
      expect(
        (platform.settings! as AppleSettings).allowBackgroundLocationUpdates,
        isFalse,
      );
    },
  );

  for (final answer in [
    LocationPermission.whileInUse,
    LocationPermission.denied,
    LocationPermission.deniedForever,
    LocationPermission.unableToDetermine,
  ]) {
    test('initial denied requests permission once: $answer', () async {
      final platform = PlatformFake()
        ..permission = LocationPermission.denied
        ..answer = answer;
      final result = GeolocatorCurrentLocation(
        platform: platform,
        now: () => now,
      ).locate(LocationAttempt());
      if (answer == LocationPermission.whileInUse) {
        await result;
        expect(platform.calls.last, 'position');
      } else {
        await expectLater(
          result,
          throwsA(
            failure(
              answer == LocationPermission.deniedForever
                  ? LocationFailure.deniedForever
                  : LocationFailure.denied,
            ),
          ),
        );
        expect(platform.calls, ['service', 'check', 'request']);
      }
    });
  }

  test(
    'disabled service and deniedForever never prompt or get position',
    () async {
      final platform = PlatformFake()..enabled = false;
      final provider = GeolocatorCurrentLocation(platform: platform);
      await expectLater(
        provider.locate(LocationAttempt()),
        throwsA(failure(LocationFailure.serviceDisabled)),
      );
      expect(platform.calls, ['service']);
      platform
        ..enabled = true
        ..permission = LocationPermission.deniedForever;
      await expectLater(
        provider.locate(LocationAttempt()),
        throwsA(failure(LocationFailure.deniedForever)),
      );
      expect(platform.calls, ['service', 'service', 'check']);
    },
  );

  for (final item in <(Position, LocationFailure)>[
    (position(latitude: double.nan), LocationFailure.invalid),
    (position(latitude: 91), LocationFailure.invalid),
    (position(accuracy: 101), LocationFailure.inaccurate),
    (position(accuracy: -1), LocationFailure.inaccurate),
    (position(accuracy: double.nan), LocationFailure.inaccurate),
    (position(hasAccuracy: false), LocationFailure.inaccurate),
    (
      position(timestamp: now.subtract(const Duration(minutes: 1))),
      LocationFailure.stale,
    ),
    (
      position(timestamp: now.add(const Duration(minutes: 1))),
      LocationFailure.stale,
    ),
  ]) {
    test(
      'reject invalid quality ${item.$2} / ${item.$1.accuracy} / ${item.$1.timestamp}',
      () async {
        final platform = PlatformFake()..read = () async => item.$1;
        await expectLater(
          GeolocatorCurrentLocation(
            platform: platform,
            now: () => now,
          ).locate(LocationAttempt()),
          throwsA(failure(item.$2)),
        );
      },
    );
  }

  for (final item in <(Object, LocationFailure)>[
    (TimeoutException('native'), LocationFailure.timeout),
    (const LocationServiceDisabledException(), LocationFailure.serviceDisabled),
    (const PermissionDeniedException('native'), LocationFailure.denied),
    (StateError('native'), LocationFailure.unavailable),
  ]) {
    test('maps plugin error ${item.$2} to Portuguese fallback', () async {
      final platform = PlatformFake()..read = () async => throw item.$1;
      await expectLater(
        GeolocatorCurrentLocation(platform: platform).locate(LocationAttempt()),
        throwsA(failure(item.$2)),
      );
      expect(
        CurrentLocationException(item.$2).message,
        contains('localização'),
      );
    });
  }

  test(
    'cancelled permission completion cannot start GPS after dispose',
    () async {
      final permission = Completer<LocationPermission>();
      final platform = PlatformFake()
        ..permission = LocationPermission.denied
        ..request = () => permission.future;
      final attempt = LocationAttempt();
      final result = GeolocatorCurrentLocation(platform: platform)
          .locate(attempt);
      await Future<void>.delayed(Duration.zero);
      attempt.cancel();
      final check = expectLater(
        result,
        throwsA(failure(LocationFailure.cancelled)),
      );
      permission.complete(LocationPermission.whileInUse);
      await check;
      expect(platform.calls, ['service', 'check', 'request']);
    },
  );
}
