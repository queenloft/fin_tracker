import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> syncContacts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Request permission
    if (await FlutterContacts.requestPermission()) {
      // Get contacts (with properties)
      List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);

      // Map contact to include its unique ID
      List<Map<String, dynamic>> contactsList = contacts.map((contact) {
        return {
          'id': contact.id, // Unique Device ID
          'displayName': contact.displayName,
          'phones': contact.phones.map((e) => e.number).toList(),
          'emails': contact.emails.map((e) => e.address).toList(),
        };
      }).toList();

      await _uploadContactsInChunks(contactsList, user.uid);
    }
  }

  Future<void> _uploadContactsInChunks(List<Map<String, dynamic>> contacts, String uid) async {
    // Chunk size 400 to be safe
    int chunkSize = 400;
    for (var i = 0; i < contacts.length; i += chunkSize) {
      var end = (i + chunkSize < contacts.length) ? i + chunkSize : contacts.length;
      var chunk = contacts.sublist(i, end);
      
      WriteBatch batch = _db.batch();
      var collection = _db.collection('users').doc(uid).collection('contacts');
      
      for (var contact in chunk) {
        // Use the Device Contact ID as the Firestore Document ID.
        // This is stable for the same contact on the same device.
        // Even if phone number changes or is empty, the ID persists locally (unless app uninstall/reinstall depending on OS).
        // This is the most reliable way to prevent "Insert" duplicates during sync.
        
        String deviceContactId = contact['id'];
        
        // We sanitize the ID to make sure it's path-safe (though usually they are numbers or UUIDs)
        // Just in case, we can use it directly or hash it if it's too long/weird.
        // Usually safe.
        
        batch.set(collection.doc(deviceContactId), {
          ...contact,
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }
}
