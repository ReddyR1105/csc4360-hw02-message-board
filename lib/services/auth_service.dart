import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  late final Stream<User?> authState = _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register(String email, String password) => _auth
      .createUserWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();
}
