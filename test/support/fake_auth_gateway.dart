import 'dart:async';

import 'package:fitcheck/auth/auth_gateway.dart';

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this._user});
  AuthUser? _user;
  final _events = StreamController<AuthUser?>.broadcast();
  AuthFailure? failure;
  int signInCalls = 0;
  @override
  AuthUser? get currentUser => _user;
  @override
  Stream<AuthUser?> get changes async* {
    yield _user;
    yield* _events.stream;
  }

  void _authenticate(String email) {
    if (failure != null) throw failure!;
    _user = AuthUser(id: email, email: email.trim());
    _events.add(_user);
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    _authenticate(email);
  }

  @override
  Future<void> createAccount(String email, String password) async =>
      _authenticate(email);
  @override
  Future<void> resetPassword(String email) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _events.add(null);
  }

  Future<void> dispose() => _events.close();
}
