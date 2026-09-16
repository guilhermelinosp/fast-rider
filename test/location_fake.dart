import 'package:fast_rider/location/current_location.dart';

class FakeLocation implements CurrentLocation {
  int calls = 0;
  final attempts = <LocationAttempt>[];
  Future<LocationFix> Function()? respond;

  @override
  Future<LocationFix> locate(LocationAttempt attempt) async {
    calls++;
    attempts.add(attempt);
    if (respond != null) return await respond!();
    throw const CurrentLocationException(LocationFailure.denied);
  }
}
