import 'package:flutter/material.dart';
import 'package:fin_tracker/main.dart' as fin_tracker;
import 'package:fin_tracker/camera_rental/main_camera_app.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/dashboard_screen.dart';

class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select App'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAppCard(
                context,
                title: 'Finance Tracker',
                icon: Icons.attach_money,
                color: Colors.green,
                onTap: () {
                  // Navigate to Finance Tracker Dashboard
                  // We might need to ensure providers are set up correctly if we just push
                  // But since we are already under the MultiProvider in main.dart, it should be fine.
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildAppCard(
                context,
                title: 'Camera Rental',
                icon: Icons.camera_alt,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MainCameraApp()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
