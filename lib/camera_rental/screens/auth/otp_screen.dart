import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../main_camera_app.dart';
import 'package:pinput/pinput.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _verifyOtp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _otpController.text,
      );

      UserCredential userCredential = await _authService.signInWithCredential(credential);
      
      // Save User to Firestore
      if (userCredential.user != null) {
        final FirestoreService firestoreService = FirestoreService();
        
        // Check if user already exists
        final existingUser = await firestoreService.getUser(userCredential.user!.uid);
        
        if (existingUser == null) {
          // Only create new user doc if it doesn't exist
          final CameraUser newUser = CameraUser(
            uid: userCredential.user!.uid,
            firstName: 'Client', // Default name, can update later
            lastName: '',
            dateOfBirth: '',
            email: '',
            mobileNumber: widget.phoneNumber,
            role: 'client',
            isVerified: true,
          );
          await firestoreService.saveUser(newUser);
        }
      }

      // Force navigation to clear stack and ensure HomeScreen loads
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainCameraApp()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: CameraRentalTheme.surfaceColor,
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: CameraRentalTheme.primaryGold),
      borderRadius: BorderRadius.circular(8),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('VERIFY PHONE'),
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
                  Icons.mark_email_read_outlined,
                  size: 64,
                  color: CameraRentalTheme.primaryGold,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verification Code',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'We have sent the code to\n${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 48),
                Pinput(
                  length: 6,
                  controller: _otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  onCompleted: (pin) => _verifyOtp(),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: CameraRentalTheme.primaryGold,
                    foregroundColor: Colors.black,
                    elevation: 5,
                    shadowColor: CameraRentalTheme.primaryGold.withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('VERIFY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
