class RideRequest {
  const RideRequest({
    required this.riderId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  final String riderId;
  final double pickupLatitude;
  final double pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  Map<String, dynamic> toJson() => {
    'pickup_latitude': pickupLatitude,
    'pickup_longitude': pickupLongitude,
    'destination_latitude': destinationLatitude,
    'destination_longitude': destinationLongitude,
  };
}

class RideResponse {
  const RideResponse({
    required this.id,
    required this.riderId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
  });

  final String id;
  final String riderId;
  final double pickupLatitude;
  final double pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;

  factory RideResponse.fromJson(Map<String, dynamic> json) {
    return RideResponse(
      id: _requiredString(json, 'id'),
      riderId: _requiredString(json, 'rider_id'),
      pickupLatitude: _requiredDouble(json, 'pickup_latitude'),
      pickupLongitude: _requiredDouble(json, 'pickup_longitude'),
      destinationLatitude: _requiredDouble(json, 'destination_latitude'),
      destinationLongitude: _requiredDouble(json, 'destination_longitude'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Missing or invalid response field: $key');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Missing or invalid response field: $key');
}
