import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../main_camera_app.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionScreen({super.key, required this.onPermissionsGranted});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isContactsGranted = false;
  bool _isLocationGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final contacts = await Permission.contacts.status;
    final location = await Permission.location.status;

    setState(() {
      _isContactsGranted = contacts.isGranted;
      _isLocationGranted = location.isGranted;
    });

    if (_isContactsGranted && _isLocationGranted) {
      widget.onPermissionsGranted();
    }
  }

  Future<void> _requestPermissions() async {
    // 1. Request Contacts
    var contactStatus = await Permission.contacts.request();
    
    // 2. Request Location (Foreground)
    var locationStatus = await Permission.location.request();

    // 3. Request Background Location (Only if Foreground is granted)
    if (locationStatus.isGranted) {
      // On Android 11+, this must be requested separately and usually shows a "Allow all the time" dialog or redirects to settings
      var bgStatus = await Permission.locationAlways.request();
      if (bgStatus.isGranted) {
        locationStatus = PermissionStatus.granted;
      }
    }

    bool isLocationAlwaysGranted = await Permission.locationAlways.isGranted;

    setState(() {
      _isContactsGranted = contactStatus.isGranted;
      _isLocationGranted = locationStatus.isGranted || isLocationAlwaysGranted;
    });

    if (_isContactsGranted && _isLocationGranted) {
      widget.onPermissionsGranted();
    } else {
       if (mounted) {
         // Check for permanently denied
         if (contactStatus.isPermanentlyDenied || locationStatus.isPermanentlyDenied) {
           _showOpenSettingsDialog();
         } else {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Permissions are required. Please grant them.')),
           );
         }
       }
    }
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
            'Permissions are permanently denied. Please open settings and allow "Contacts" and "Location" (Allow all the time) manually.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: CameraRentalTheme.darkGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.security_outlined,
                  size: 80,
                  color: CameraRentalTheme.primaryGold,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Permissions Required',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'To verify your identity and ensure secure rentals, we need the following permissions:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 48),
                _buildPermissionItem(
                  icon: Icons.contacts,
                  title: 'Contact Sync',
                  description: 'Used to verify alternate contact details.',
                  isGranted: _isContactsGranted,
                ),
                const SizedBox(height: 24),
                _buildPermissionItem(
                  icon: Icons.location_on,
                  title: 'Location Tracking',
                  description: 'Required to track rented equipment in real-time.',
                  isGranted: _isLocationGranted,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: CameraRentalTheme.primaryGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 5,
                    shadowColor: CameraRentalTheme.primaryGold.withOpacity(0.5),
                  ),
                  child: const Text(
                    'ACCEPT & GRANT PERMISSIONS',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: widget.onPermissionsGranted,
                  child: Text(
                    'Check Again / Continue',
                    style: TextStyle(color: CameraRentalTheme.primaryGold.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
  }) {
    Color color = isGranted ? Colors.greenAccent : CameraRentalTheme.primaryGold;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CameraRentalTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green.withOpacity(0.3) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isGranted ? Icons.check_circle : icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
