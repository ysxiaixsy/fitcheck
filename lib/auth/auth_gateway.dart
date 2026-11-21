import 'package:firebase_auth/firebase_auth.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email});
  final String id, email;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

abstract interface class AuthGateway {
  AuthUser? get currentUser;
  Stream<AuthUser?> get changes;
  Future<void> signIn(String email, String password);
  Future<void> createAccount(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._auth);
  final FirebaseAuth _auth;
  AuthUser? _user(User? user) =>
      user == null ? null : AuthUser(id: user.uid, email: user.email ?? '');
  @override
  AuthUser? get currentUser => _user(_auth.currentUser);
  @override
  Stream<AuthUser?> get changes => _auth.authStateChanges().map(_user);
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Your email or password did not match. Please try again.',
        'email-already-in-use' =>
          'This email already has an account. Try signing in.',
        'weak-password' =>
          'Choose a stronger password with at least 8 characters.',
        'too-many-requests' =>
          'Too many attempts. Wait a moment and try again.',
        'network-request-failed' =>
          'Could not connect. Check your connection and try again.',
        'user-disabled' => 'This account is disabled. Contact the app owner.',
        _ => 'Could not complete this request. Please try again.',
      });
    } catch (_) {
      throw const AuthFailure('Could not connect. Please try again.');
    }
  }

  @override
  Future<void> signIn(String email, String password) => _run(() async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<void> createAccount(String email, String password) => _run(() async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<void> resetPassword(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email.trim()));
  @override
  Future<void> signOut() => _run(_auth.signOut);
}
