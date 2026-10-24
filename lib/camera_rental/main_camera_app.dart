import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/admin/client_list_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/client/home_screen.dart';
import 'screens/intro/permission_screen.dart';

class MainCameraApp extends StatefulWidget {
  const MainCameraApp({super.key});

  @override
  State<MainCameraApp> createState() => _MainCameraAppState();
}

class _MainCameraAppState extends State<MainCameraApp> {
  bool _permissionsGranted = false;
  bool _checkingPermissions = true;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final contacts = await Permission.contacts.status;
    final location = await Permission.location.status;

    if (mounted) {
      setState(() {
        _permissionsGranted = contacts.isGranted && location.isGranted;
        _checkingPermissions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPermissions) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Apply the Custom Theme to the entire Camera Rental App section
    return Theme(
      data: CameraRentalTheme.darkTheme,
      child: Builder(builder: (context) {
        if (!_permissionsGranted) {
          return PermissionScreen(
            onPermissionsGranted: () {
              setState(() {
                _permissionsGranted = true;
              });
            },
          );
        }

        final AuthService authService = AuthService();

        return StreamBuilder<User?>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasData) {
              final User user = snapshot.data!;
              if (user.isAnonymous) {
                 return const ClientListScreen();
              }
              return const HomeScreen();
            }

            return const LoginScreen();
          },
        );
      }),
    );
  }
}
