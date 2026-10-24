import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'camera_rental/core/theme/app_theme.dart';
import 'camera_rental/main_camera_app.dart';
import 'services/notification_service.dart';

import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Require Google Maps Renderer to be the latest version to avoid legacy renderer gray screen issues
  final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
    mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
  }

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize notification service
  await NotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camspot',
      debugShowCheckedModeBanner: false,
      theme: CameraRentalTheme.darkTheme,
      home: const MainCameraApp(),
    );
  }
}
