import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:fast_rider/api/location_services.dart';

enum LocationFailure {
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  inaccurate,
  stale,
  invalid,
  unavailable,
  cancelled,
}

class CurrentLocationException implements Exception {
  const CurrentLocationException(this.reason);
  final LocationFailure reason;

  String get message => switch (reason) {
    LocationFailure.denied => 'Permissão de localização não concedida. Tente novamente para definir o embarque.',
    LocationFailure.deniedForever =>
      'A permissão de localização está bloqueada nos ajustes do aparelho.',
    LocationFailure.serviceDisabled =>
      'O serviço de localização está desativado. Ative-o e tente novamente.',
    LocationFailure.timeout =>
      'A localização demorou a responder. Tente novamente.',
    LocationFailure.inaccurate =>
      'A localização está imprecisa para definir o embarque. Tente novamente.',
    LocationFailure.stale =>
      'A localização recebida está desatualizada. Tente novamente.',
    LocationFailure.invalid =>
      'A localização retornou coordenadas inválidas. Tente novamente.',
    LocationFailure.unavailable =>
      'Não foi possível obter sua localização. Tente novamente.',
    LocationFailure.cancelled =>
      'Captura de localização interrompida. Tente novamente.',
  };
  @override
  String toString() => '${reason.name}: $message';
}

/// Invalidates later permission/GPS completions, including before sensor access.
/// The OS permission dialog itself cannot be dismissed programmatically.
class LocationAttempt {
  bool _cancelled = false;
  VoidCallback? onCancel;
  bool get cancelled => _cancelled;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    onCancel?.call();
  }

  void checkActive() {
    if (_cancelled) {
      throw const CurrentLocationException(LocationFailure.cancelled);
    }
  }
}

class LocationFix {
  const LocationFix({
    required this.point,
    required this.accuracyMeters,
    required this.timestamp,
  });
  final LatLng point;

  /// Null means that the platform did not report horizontal accuracy.
  final double? accuracyMeters;
  final DateTime timestamp;

  void validate(DateTime now) {
    if (!validCoordinate(point)) {
      throw const CurrentLocationException(LocationFailure.invalid);
    }
    final accuracy = accuracyMeters;
    // Product guardrail, NOT a promise that the pickup is within 100 metres.
    if (accuracy == null ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 100) {
      throw const CurrentLocationException(LocationFailure.inaccurate);
    }
    final age = now.difference(timestamp);
    if (age > const Duration(seconds: 30) ||
        age < const Duration(seconds: -5)) {
      throw const CurrentLocationException(LocationFailure.stale);
    }
  }
}

abstract interface class CurrentLocation {
  Future<LocationFix> locate(LocationAttempt attempt);
}

/// Apple plugin 2.3.14 does not cancel its native one-time manager on Dart
/// timeout. Use CoreLocation.requestLocation plus native timeout/cancellation
/// on iOS instead. Permissions still use Geolocator's maintained adapter.
CurrentLocation deviceCurrentLocation() => GeolocatorCurrentLocation(
  readPosition: defaultTargetPlatform == TargetPlatform.iOS
      ? IosSinglePosition().read
      : null,
);

typedef PositionReader = Future<Position> Function(
  LocationAttempt attempt,
  LocationSettings settings,
);

class IosSinglePosition {
  IosSinglePosition({
    this.channel = const MethodChannel('fast_rider/current_position'),
  });
  final MethodChannel channel;
  static int _nextId = 0;

  Future<Position> read(
    LocationAttempt attempt,
    LocationSettings settings,
  ) async {
    attempt.checkActive();
    final id = '${++_nextId}';
    attempt.onCancel = () {
      unawaited(
        channel.invokeMethod<void>('cancel', {'id': id}).catchError((
          Object error,
          StackTrace stack,
        ) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'current_location',
              context: ErrorDescription('cancelling native location capture'),
            ),
          );
        }),
      );
    };
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('capture', {
        'id': id,
        'timeoutMs':
            (settings.timeLimit ?? const Duration(seconds: 15)).inMilliseconds,
      });
      if (data == null) {
        throw const CurrentLocationException(LocationFailure.invalid);
      }
      return Position.fromMap(data);
    } on PlatformException catch (error) {
      throw CurrentLocationException(switch (error.code) {
        'timeout' => LocationFailure.timeout,
        'cancelled' => LocationFailure.cancelled,
        'denied' => LocationFailure.denied,
        'serviceDisabled' => LocationFailure.serviceDisabled,
        _ => LocationFailure.unavailable,
      });
    } on MissingPluginException {
      throw const CurrentLocationException(LocationFailure.unavailable);
    } on CurrentLocationException {
      rethrow;
    } catch (_) {
      throw const CurrentLocationException(LocationFailure.unavailable);
    } finally {
      attempt.onCancel = null;
    }
  }
}

/// One current-position request, never last-known, reverse geocoding or streams.
class GeolocatorCurrentLocation implements CurrentLocation {
  GeolocatorCurrentLocation({
    GeolocatorPlatform? platform,
    DateTime Function()? now,
    this._readPosition,
  }) : _platform = platform ?? GeolocatorPlatform.instance,
       _now = now ?? DateTime.now;
  final GeolocatorPlatform _platform;
  final DateTime Function() _now;
  final PositionReader? _readPosition;
  static const deadline = Duration(seconds: 30);

  @override
  Future<LocationFix> locate(LocationAttempt attempt) async {
    try {
      return await _capture(attempt).timeout(deadline);
    } on CurrentLocationException {
      rethrow;
    } on TimeoutException {
      throw const CurrentLocationException(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const CurrentLocationException(LocationFailure.serviceDisabled);
    } on PermissionDeniedException {
      throw const CurrentLocationException(LocationFailure.denied);
    } catch (_) {
      throw const CurrentLocationException(LocationFailure.unavailable);
    } finally {
      attempt.cancel();
    }
  }

  Future<LocationFix> _capture(LocationAttempt attempt) async {
    attempt.checkActive();
    final enabled = await _platform.isLocationServiceEnabled();
    attempt.checkActive();
    if (!enabled) {
      throw const CurrentLocationException(LocationFailure.serviceDisabled);
    }
    var permission = await _platform.checkPermission();
    attempt.checkActive();
    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
      attempt.checkActive();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const CurrentLocationException(LocationFailure.deniedForever);
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const CurrentLocationException(LocationFailure.denied);
    }
    final settings = AppleSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
      allowBackgroundLocationUpdates: false,
      showBackgroundLocationIndicator: false,
    );
    final position = _readPosition != null
        ? await _readPosition(attempt, settings)
        : await _platform.getCurrentPosition(locationSettings: settings);
    attempt.checkActive();
    final fix = LocationFix(
      point: LatLng(position.latitude, position.longitude),
      accuracyMeters: position.hasAccuracy ? position.accuracy : null,
      timestamp: position.timestamp,
    );
    fix.validate(_now());
    return fix;
  }
}
