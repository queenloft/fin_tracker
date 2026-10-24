import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'client_list_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() async {
    if (_emailController.text == 'admin@camera.com' && _passwordController.text == 'admin123') {
      try {
        // Force sign out of any existing session (e.g. Client Phone Auth)
        // to ensure we enter a clean "Admin" state (Anonymous)
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }

        // Authenticate anonymously
        await FirebaseAuth.instance.signInAnonymously();
        
        // Navigation is handled by the auth state stream in MainCameraApp
        if (mounted) {
           Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          // Show full error
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Login Failed'),
              content: Text('Error: $e\n\nMake sure "Anonymous" sign-in is enabled in Firebase Console!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                )
              ],
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Admin Credentials')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('ADMIN ACCESS'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: CameraRentalTheme.darkGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 80,
                  color: CameraRentalTheme.primaryGold,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Secure Login',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticating with Camspot Server',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: CameraRentalTheme.primaryGold,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.email, color: CameraRentalTheme.primaryGold),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CameraRentalTheme.primaryGold, width: 2),
                    ),
                    filled: true,
                    fillColor: CameraRentalTheme.surfaceColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  cursorColor: CameraRentalTheme.primaryGold,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.lock, color: CameraRentalTheme.primaryGold),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CameraRentalTheme.primaryGold, width: 2),
                    ),
                    filled: true,
                    fillColor: CameraRentalTheme.surfaceColor,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: CameraRentalTheme.primaryGold,
                    foregroundColor: Colors.black,
                    elevation: 5,
                    shadowColor: CameraRentalTheme.primaryGold.withOpacity(0.5),
                  ),
                  child: const Text(
                    'AUTHENTICATE',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
