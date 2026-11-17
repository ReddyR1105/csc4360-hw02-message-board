import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/board_models.dart';

class UserRecordService {
  UserRecordService(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _record(String uid) =>
      _db.collection('users').doc(uid);

  Future<BoardProfile?> load(String uid) async {
    final doc = await _record(uid).get();
    return doc.exists ? BoardProfile.fromSnapshot(doc) : null;
  }

  Future<BoardProfile> saveUserRecord(String uid, ProfileDetails details) {
    final doc = _record(uid);
    return _db.runTransaction((transaction) async {
      final current = await transaction.get(doc);
      if (current.exists) return BoardProfile.fromSnapshot(current);
      final profile = BoardProfile(
        uid,
        details.firstName.trim(),
        details.lastName.trim(),
      );
      transaction.set(doc, {
        'uid': uid,
        'firstName': profile.firstName,
        'lastName': profile.lastName,
        'role': ProfileDetails.role,
        'registrationDateTime': FieldValue.serverTimestamp(),
      });
      return profile;
    });
  }
}
