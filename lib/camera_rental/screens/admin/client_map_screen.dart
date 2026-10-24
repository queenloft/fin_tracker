import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';

class ClientMapScreen extends StatefulWidget {
  final CameraUser user;

  const ClientMapScreen({super.key, required this.user});

  @override
  State<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends State<ClientMapScreen> {
  GoogleMapController? _mapController;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tracking ${widget.user.firstName}')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .collection('locations')
            .doc('current')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading location'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.location_disabled, size: 64, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text('No location data available', style: TextStyle(color: Colors.white, fontSize: 18)),
                   const SizedBox(height: 8),
                   const Text('Ask client to click "Start Tracking"', style: TextStyle(color: Colors.grey)),
                   const SizedBox(height: 4),
                   Text('Path: users/${widget.user.uid}/locations/current', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                ],
              ),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          double lat = data['latitude'];
          double lng = data['longitude'];
          Timestamp? timestamp = data['timestamp'];

          LatLng position = LatLng(lat, lng);

          // Update camera if map is created
          if (_mapController != null) {
            _mapController!.animateCamera(CameraUpdate.newLatLng(position));
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: position,
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('client'),
                    position: position,
                    infoWindow: InfoWindow(
                      title: widget.user.firstName,
                      snippet: 'Last updated: ${timestamp?.toDate()}',
                    ),
                  ),
                },
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(
                  color: CameraRentalTheme.cardBackground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.circle, color: Colors.greenAccent, size: 12),
                            const SizedBox(width: 8),
                            Text(
                              'Status: ${data['rentalStatus'] ?? 'Unknown'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                         Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildInfoBadge(Icons.gps_fixed, '${data['accuracy']?.toStringAsFixed(1)} m'),
                            if (timestamp != null)
                             _buildInfoBadge(Icons.access_time, _formatTime(timestamp)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: CameraRentalTheme.primaryGold),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
