import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileDetails {
  const ProfileDetails(this.firstName, this.lastName);
  final String firstName;
  final String lastName;
  static const role = 'member';
}

class BoardProfile extends ProfileDetails {
  const BoardProfile(this.uid, super.firstName, super.lastName);

  factory BoardProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return BoardProfile(
      doc.id,
      data['firstName'] as String,
      data['lastName'] as String,
    );
  }

  final String uid;
  String get displayName => '$firstName $lastName';
}

class BoardMessage {
  const BoardMessage({
    required this.id,
    required this.text,
    required this.authorUid,
    required this.authorName,
    this.createdAt,
    this.editedAt,
  });

  factory BoardMessage.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return BoardMessage(
      id: doc.id,
      text: data['text'] as String,
      authorUid: data['authorUid'] as String,
      authorName: data['authorName'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String text;
  final String authorUid;
  final String authorName;
  final DateTime? createdAt;
  final DateTime? editedAt;
}
