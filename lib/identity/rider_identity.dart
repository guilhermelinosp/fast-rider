import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class RiderIdentity {
  RiderIdentity({this.preferences, Random? random})
    : _random = random ?? Random.secure();

  static const storageKey = 'rider_id';
  static final _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final SharedPreferences? preferences;
  final Random _random;
  Future<String>? _riderIdFuture;

  Future<String> getOrCreateRiderId() {
    return _riderIdFuture ??= _loadOrCreateRiderId();
  }

  Future<String> _loadOrCreateRiderId() async {
    final storedPreferences =
        preferences ?? await SharedPreferences.getInstance();
    final storedRiderId = storedPreferences.getString(storageKey);
    if (storedRiderId != null && _uuidV4Pattern.hasMatch(storedRiderId)) {
      return storedRiderId;
    }

    final riderId = _generateUuidV4();
    await storedPreferences.setString(storageKey, riderId);
    return riderId;
  }

  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String byteToHex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    final hex = bytes.map(byteToHex).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
