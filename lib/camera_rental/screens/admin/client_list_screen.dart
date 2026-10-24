import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';
import 'client_details_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  
  Future<void> _refresh() async {
    // Rebuild the widget to resubscribe to the stream (simulating a refetch)
    setState(() {});
    // Small delay for UX so the spinner is visible
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white70),
            onPressed: _refresh,
            tooltip: 'Refresh List',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: CameraRentalTheme.darkGradient,
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: CameraRentalTheme.accentRed)));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: const Center(child: Text('No clients found', style: TextStyle(color: Colors.white70))),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              color: CameraRentalTheme.primaryGold,
              backgroundColor: CameraRentalTheme.surfaceColor,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  CameraUser user = CameraUser.fromMap(doc.data() as Map<String, dynamic>);

                  return Card(
                    color: CameraRentalTheme.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: CameraRentalTheme.primaryGold,
                        foregroundColor: Colors.black,
                        child: Text(
                          user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        user.firstName.isNotEmpty ? user.firstName : 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(user.mobileNumber, style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, color: CameraRentalTheme.primaryGold, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClientDetailsScreen(user: user),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
