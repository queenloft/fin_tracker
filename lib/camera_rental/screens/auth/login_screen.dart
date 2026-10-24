import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../admin/admin_login_screen.dart';
import 'otp_screen.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  String _completePhoneNumber = '';
  bool _isLoading = false;

  void _sendOtp() async {
    if (_completePhoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _authService.verifyPhoneNumber(
      phoneNumber: _completePhoneNumber,
      verificationCompleted: (credential) async {
        // Auto-resolution (Android only)
        await _authService.signInWithCredential(credential);
        // Navigation will be handled by the auth state stream in main_camera_app
      },
      verificationFailed: (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.message}')),
        );
      },
      codeSent: (verificationId, resendToken) {
        setState(() {
          _isLoading = false;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              verificationId: verificationId,
              phoneNumber: _completePhoneNumber,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {
        // Handle timeout
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CAMSPOT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                  Icons.camera_enhance_outlined,
                  size: 80,
                  color: CameraRentalTheme.primaryGold,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your mobile number to look up your account',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                IntlPhoneField(
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    counterText: '',
                  ),
                  style: const TextStyle(color: Colors.white),
                  dropdownTextStyle: const TextStyle(color: Colors.white),
                  initialCountryCode: 'IN',
                  cursorColor: CameraRentalTheme.primaryGold,
                  onChanged: (phone) {
                    _completePhoneNumber = phone.completeNumber;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: CameraRentalTheme.primaryGold,
                    foregroundColor: Colors.black,
                    elevation: 5,
                    shadowColor: CameraRentalTheme.primaryGold.withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'CONTINUE',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
                    );
                  },
                  child: Text(
                    'Admin Portal Access',
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
}
