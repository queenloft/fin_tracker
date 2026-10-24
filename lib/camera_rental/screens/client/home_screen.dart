import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import 'offers_widget.dart';
import '../../core/services/location_service.dart';
import '../../core/services/contact_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'profile_update_screen.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContactService _contactService = ContactService();
  final LocationService _locationService = LocationService();
  bool _isSyncing = false;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _locationService.initialize();
    
    // Auto-sync contacts and check profile after build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkProfileCompleteness();
      _syncContacts();
      
      // Auto-start tracking if not already active
      if (!_isTracking) {
        // Double check service status to match UI state
        final service = FlutterBackgroundService();
        var isRunning = await service.isRunning();
        if (!isRunning) {
          _toggleTracking();
        } else {
          // Sync UI if service is already running
          setState(() {
            _isTracking = true;
          });
        }
      }
    });
  }

  Future<void> _checkProfileCompleteness() async {
    print('Checking profile completeness...');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final String? firstName = data['firstName'];
          final String? email = data['email'];

          print('Profile Data: firstName=$firstName, email=$email');

          if (firstName == null || firstName.trim().isEmpty || email == null || email.trim().isEmpty) {
            print('Profile incomplete. Navigating to update screen...');
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileUpdateScreen()),
              );
            }
          } else {
            print('Profile is complete.');
          }
        } else {
          print('User document does not exist. Navigating to update screen...');
          // Doc doesn't exist? Force update
           if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileUpdateScreen()),
              );
            }
        }
      } catch (e) {
        print('Error checking profile: $e');
      }
    } else {
      print('No user logged in during check.');
    }
  }

  void _toggleTracking() async {
    if (_isTracking) {
      await _locationService.stopTracking();
    } else {
      await _locationService.startTracking();
    }
    setState(() {
      _isTracking = !_isTracking;
    });
  }

  void _syncContacts() async {
    setState(() {
      _isSyncing = true;
    });
    try {
      await _contactService.syncContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts synced successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync contacts: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: CameraRentalTheme.darkGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeHeader(),
                      const SizedBox(height: 24),
                      _buildActionGrid(),
                      const SizedBox(height: 32),
                      const Text(
                        'Exclusive Offers',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CameraRentalTheme.primaryGold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const OffersWidget(), // Assuming OffersWidget adapts or we rely on generic card theme
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.camera_enhance, color: CameraRentalTheme.primaryGold),
          const Text(
            'CAMSPOT',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileUpdateScreen(canGoBack: true),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CameraRentalTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: CameraRentalTheme.primaryGold.withOpacity(0.2),
              child: const Icon(Icons.person, color: CameraRentalTheme.primaryGold),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello Client',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Tap to edit profile',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildActionCard(
          title: _isSyncing ? 'Syncing...' : 'Sync Contacts',
          subtitle: 'Backup your list',
          icon: Icons.sync,
          isActive: true, // Always active visually
          isLoading: _isSyncing,
          onTap: _isSyncing ? null : _syncContacts,
        ),
        _buildActionCard(
          title: _isTracking ? 'Stop Tracking' : 'Start Rent',
          subtitle: _isTracking ? 'Tracking Active' : 'Start Secure Session',
          icon: _isTracking ? Icons.location_off : Icons.location_on,
          isActive: _isTracking,
          isHighAlert: _isTracking,
          onTap: _toggleTracking,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isActive = false,
    bool isHighAlert = false,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    Color baseColor = isHighAlert ? CameraRentalTheme.accentRed : CameraRentalTheme.primaryGold;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CameraRentalTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? baseColor.withOpacity(0.5) : Colors.white10,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? [
             BoxShadow(color: baseColor.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
               SizedBox(height: 30, width: 30, child: CircularProgressIndicator(color: baseColor))
            else
               Icon(icon, size: 32, color: baseColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
