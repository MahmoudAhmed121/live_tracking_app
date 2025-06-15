import 'package:flutter/material.dart';
import 'package:live_tracking_app/google_maps/presentation/screens/order_track_map_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
     title: 'Live Tracking App',
     home: OrderTrackMapScreen(),
    );
  }
}
