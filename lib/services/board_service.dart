import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/board_models.dart';
import 'auth_service.dart';

class PendingPost {
  const PendingPost(this.id, this.text);
  final String id;
  final String text;

  factory PendingPost.decode(String value) {
    final fields = jsonDecode(value) as Map<String, dynamic>;
    return PendingPost(fields['id'] as String, fields['text'] as String);
  }

  String encode() => jsonEncode({'id': id, 'text': text});
}

class BoardService {
  BoardService(this._db, this._auth, this.profile);
  final FirebaseFirestore _db;
  final AuthService _auth;
  final BoardProfile profile;
  final _prefs = SharedPreferencesAsync();

  String get _draftKey => 'pending/${_db.app.options.projectId}/${profile.uid}';
  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');
  CollectionReference<Map<String, dynamic>> get _receipts =>
      _db.collection('users').doc(profile.uid).collection('postReceipts');

  void _confirmSession() {
    if (_auth.currentUser?.uid != profile.uid) {
      throw StateError('Your session changed. Sign in again.');
    }
  }

  Future<PendingPost?> loadPending() async {
    final value = await _prefs.getString(_draftKey);
    return value == null ? null : PendingPost.decode(value);
  }

  Future<PendingPost> savePending(String text) async {
    _confirmSession();
    final existing = await loadPending();
    if (existing != null) return existing;
    final post = PendingPost(_messages.doc().id, text.trim());
    await _prefs.setString(_draftKey, post.encode());
    return post;
  }

  Future<void> postMessage(PendingPost post) async {
    _confirmSession();
    final message = _messages.doc(post.id);
    final receipt = _receipts.doc(post.id);
    try {
      await _db.runTransaction((transaction) async {
        if ((await transaction.get(receipt)).exists) return;
        transaction.set(message, {
          'text': post.text,
          'authorUid': profile.uid,
          'authorName': profile.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'editedAt': null,
        });
        transaction.set(receipt, {'createdAt': FieldValue.serverTimestamp()});
      });
    } on FirebaseException catch (error) {
      // A racing commit can fail rules after the other attempt creates the receipt.
      if (error.code != 'permission-denied' &&
          error.code != 'already-exists' &&
          error.code != 'aborted') {
        rethrow;
      }
      final saved = await receipt.get(const GetOptions(source: Source.server));
      if (!saved.exists) rethrow;
    }
    await _prefs.remove(_draftKey);
  }

  Stream<List<BoardMessage>> messageBoard() => _messages
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((result) => result.docs.map(BoardMessage.fromSnapshot).toList());

  Future<void> editMessage(String messageId, String newText) {
    _confirmSession();
    return _messages.doc(messageId).update({
      'text': newText.trim(),
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String messageId) {
    _confirmSession();
    return _messages.doc(messageId).delete();
  }
}
