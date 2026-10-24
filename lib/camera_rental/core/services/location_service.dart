import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 1. Initialize Dart & Flutter bindings
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialize Firebase (Robustly)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase init error (ignorable if already init): $e');
  }

  // 3. Setup UID
  String? targetUid;
  final prefs = await SharedPreferences.getInstance();
  targetUid = prefs.getString('tracking_uid');

  // 4. Listen for Service Controls
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('setUserData').listen((event) async {
    if (event != null && event.containsKey('uid')) {
      targetUid = event['uid'] as String?;
      await prefs.setString('tracking_uid', targetUid ?? ''); 
      print('Background Service: User UID set to $targetUid');
    }
  });

  // 5. Start Location Stream (Better than Timer)
  final LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // Update every 10 meters
  );

  Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
      // Refresh UID if null
      if (targetUid == null) {
         targetUid = prefs.getString('tracking_uid');
      }
      
      // Fallback: Try to get from Auth if initialized
      if (targetUid == null || targetUid!.isEmpty) {
         try {
           targetUid = FirebaseAuth.instance.currentUser?.uid;
         } catch (_) {}
      }

      if (targetUid != null && targetUid!.isNotEmpty) {
        try {
           await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .collection('locations')
            .doc('current') // Overwrite 'current' for real-time map
            .set({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'timestamp': FieldValue.serverTimestamp(),
              'accuracy': position.accuracy,
              'speed': position.speed,
              'rentalStatus': 'Active',
              'updatedAt': DateTime.now().toIso8601String(),
            }, SetOptions(merge: true));
            
           print('Location Saved: ${position.latitude}, ${position.longitude} for $targetUid');
           
           // Optional: Update Notification
           if (service is AndroidServiceInstance) {
             service.setForegroundNotificationInfo(
               title: "Camspot Service",
               content: "Tracking Active: Lat ${position.latitude.toStringAsFixed(4)}",
             );
           }
        } catch (e) {
           print('Firestore Write Error: $e');
        }
      } else {
        print('Warning: No UID found, cannot save location.');
      }
  });
}

class LocationService {
  static const String notificationChannelId = 'my_foreground';
  static const int notificationId = 888;

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'MY FOREGROUND SERVICE',
      description: 'This channel is used for important notifications.',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // We start it manually when rental is active
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Camspot Service',
        initialNotificationContent: 'Tracking Camspot location for safety',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startTracking() async {
    // Request permissions first
    if (await Permission.location.request().isGranted) {
      // For background, we might need 'always'
      // Try to request always, but if denied, 'while in use' might suffice for foreground service
      var status = await Permission.locationAlways.request();
      
      if (status.isGranted || await Permission.location.isGranted) {
        final service = FlutterBackgroundService();
        var isRunning = await service.isRunning();
        if (!isRunning) {
          await service.startService();
        }
        
        // Save UID to SharedPrefs for reliable background access
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('tracking_uid', user.uid);
            
            // Also send via invoke as immediate backup
            service.invoke("setUserData", {"uid": user.uid});
        }
      } else {
        // Handle permission denied
      }
    }
  }

  Future<void> stopTracking() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke("stopService");
    }
  }
}
