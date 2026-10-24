import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client_map_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';

class ClientDetailsScreen extends StatefulWidget {
  final CameraUser user;

  const ClientDetailsScreen({super.key, required this.user});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  int _limit = 20;
  final int _limitIncrement = 20;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text; // Keep case for better Firestore matching if using exact
      });
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  void _loadMore() {
    setState(() {
      _limit += _limitIncrement;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launchDialer(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching dialer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CameraRentalTheme.darkBackground,
      appBar: AppBar(
        title: Text('${widget.user.firstName}\'s Profile', style: const TextStyle(color: CameraRentalTheme.primaryGold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: CameraRentalTheme.darkGradient,
        ),
        child: Column( // Changed to Column for Expanded list
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildInfoCard(context),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search contacts (Case Sensitive)...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.search, color: CameraRentalTheme.primaryGold),
                  fillColor: CameraRentalTheme.cardBackground,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Synced Contacts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CameraRentalTheme.primaryGold),
              ),
            ),
            
            Expanded(
              child: _buildContactsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      color: CameraRentalTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: CameraRentalTheme.primaryGold,
              child: Text(
                widget.user.firstName.isNotEmpty ? widget.user.firstName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 32, color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.user.firstName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.phone, 'Mobile', widget.user.mobileNumber),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.email, 'Email', widget.user.email.isNotEmpty ? widget.user.email : 'Not provided'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClientMapScreen(user: widget.user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text('TRACK', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CameraRentalTheme.primaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        var snapshot = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.user.uid)
                            .collection('locations')
                            .doc('current')
                            .get();
                        
                        if (snapshot.exists && snapshot.data() != null) {
                          var data = snapshot.data()!;
                          double lat = data['latitude'];
                          double lng = data['longitude'];
                          
                          final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                          
                          if (await canLaunchUrl(googleMapsUrl)) {
                             await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
                          } else {
                             throw 'Could not launch Maps';
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No location history.')),
                            );
                          }
                        }
                      } catch (e) {
                        print('Nav error: $e');
                      }
                    },
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('NAVIGATE', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            GestureDetector(
              onTap: label == 'Mobile' ? () => _launchDialer(value) : null,
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 16,
                  decoration: label == 'Mobile' ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: CameraRentalTheme.primaryGold
                )
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactsList() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('contacts');

    // Server-side filtering and sorting
    // Note: Firestore string search is limited. We use startAt/endAt pattern.
    if (_searchQuery.isNotEmpty) {
      query = query
        .orderBy('displayName')
        .startAt([_searchQuery])
        .endAt(['$_searchQuery\uf8ff'])
        .limit(50); // Search limit
    } else {
      query = query.limit(_limit); // Pagination limit
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No contacts found.', style: TextStyle(color: Colors.grey)));
        }

        var docs = snapshot.data!.docs;

        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: docs.length + 1, // +1 for loader/end padding
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == docs.length) {
              return const SizedBox(height: 50); // Bottom padding/loader space
            }

            var data = docs[index].data() as Map<String, dynamic>;
            String name = data['displayName'] ?? 'Unknown';
            List phones = data['phones'] ?? [];
            String phoneDisplay = phones.isNotEmpty ? phones.first.toString() : 'No number';
            
            return Container(
              decoration: BoxDecoration(
                color: CameraRentalTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person, size: 20),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  phoneDisplay,
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: const Icon(Icons.call, color: Colors.greenAccent, size: 20),
                onTap: () {
                  if (phones.isNotEmpty) {
                    _launchDialer(phones.first.toString());
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
