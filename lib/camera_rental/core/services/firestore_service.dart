import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveUser(CameraUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<CameraUser?> getUser(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return CameraUser.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}
