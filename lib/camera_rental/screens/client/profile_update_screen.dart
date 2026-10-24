import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProfileUpdateScreen extends StatefulWidget {
  final bool canGoBack;
  const ProfileUpdateScreen({super.key, this.canGoBack = false});

  @override
  State<ProfileUpdateScreen> createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _emailController.text = data['email'] ?? '';
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'firstName': _firstNameController.text.trim(),
          'email': _emailController.text.trim(),
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.of(context).pop(true); // Return Success
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prevent back navigation without saving ONLY if canGoBack is false
    return Theme(
      data: CameraRentalTheme.darkTheme,
      child: PopScope(
        canPop: widget.canGoBack,
        child: Scaffold(
          backgroundColor: CameraRentalTheme.darkBackground,
          appBar: AppBar(
            title: const Text('Complete Your Profile', style: TextStyle(color: CameraRentalTheme.primaryGold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: widget.canGoBack, // Show back button if allowed
          ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_circle, size: 80, color: CameraRentalTheme.primaryGold),
                const SizedBox(height: 24),
                const Text(
                  'We need a few details to get you started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _firstNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person, color: CameraRentalTheme.primaryGold),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your first name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email, color: CameraRentalTheme.primaryGold),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || !value.contains('@') ? 'Please enter a valid email' : null,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black))
                      : const Text('SAVE & CONTINUE'),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
