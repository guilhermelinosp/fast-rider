import 'package:flutter/material.dart';

import 'package:fast_rider/api/ride_api_client.dart';
import 'package:fast_rider/config/app_config.dart';
import 'package:fast_rider/identity/rider_identity.dart';
import 'package:fast_rider/pages/ride_page.dart';
import 'package:fast_rider/ride_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  final riderId = await RiderIdentity().getOrCreateRiderId();
  final apiClient = HttpRideApiClient(baseUrl: AppConfig.baseUrl);
  runApp(RiderApp(apiClient: apiClient, riderId: riderId));
}

class RiderApp extends StatelessWidget {
  const RiderApp({super.key, required this.apiClient, required this.riderId});

  final RideApiClient apiClient;
  final String riderId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fast Rider',
      debugShowCheckedModeBanner: false,
      theme: RideTheme.data,
      home: RidePage(apiClient: apiClient, riderId: riderId),
    );
  }
}
