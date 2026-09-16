import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fast_rider/identity/rider_identity.dart';

void main() {
  test(
    'generates one UUID v4 and remains stable for the identity lifetime',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final identity = RiderIdentity(
        preferences: preferences,
        random: Random(7),
      );

      final firstId = await identity.getOrCreateRiderId();
      final secondId = await identity.getOrCreateRiderId();

      expect(firstId, secondId);
      expect(
        firstId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            caseSensitive: false,
          ),
        ),
      );
      expect(preferences.getString(RiderIdentity.storageKey), firstId);
    },
  );

  test('loads the persisted UUID instead of generating a new one', () async {
    const persistedId = '550e8400-e29b-41d4-a716-446655440000';
    SharedPreferences.setMockInitialValues({
      RiderIdentity.storageKey: persistedId,
    });
    final preferences = await SharedPreferences.getInstance();

    final identity = RiderIdentity(
      preferences: preferences,
      random: _FailingRandom(),
    );

    expect(await identity.getOrCreateRiderId(), persistedId);
  });
}

class _FailingRandom implements Random {
  @override
  bool nextBool() => throw StateError('A new UUID should not be generated');

  @override
  double nextDouble() => throw StateError('A new UUID should not be generated');

  @override
  int nextInt(int max) =>
      throw StateError('A new UUID should not be generated');
}
