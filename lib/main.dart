import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:fast_rider/api/location_services.dart';
import 'package:fast_rider/config/app_config.dart';
import 'package:fast_rider/location/current_location.dart';
import 'package:fast_rider/pages/ride_page.dart';
import 'package:fast_rider/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig();
  config.validate();
  runApp(const RiderApp(config: config));
}

class RiderApp extends StatelessWidget {
  const RiderApp({
    super.key,
    this.config = const AppConfig(),
    this.geocoder,
    this.router,
    this.tileProvider,
    this.currentLocation,
  });

  final AppConfig config;
  final Geocoder? geocoder;
  final RoadRouter? router;
  final TileProvider? tileProvider;
  final CurrentLocation? currentLocation;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fast Rider',
      debugShowCheckedModeBanner: false,
      theme: RideTheme.data,
      home: RidePage(
        config: config,
        geocoder: geocoder,
        router: router,
        tileProvider: tileProvider,
        currentLocation: currentLocation,
      ),
    );
  }
}
