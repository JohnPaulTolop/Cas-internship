import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'auth_service.dart';
import 'practicum_repository.dart';

class AppController extends ChangeNotifier {
  AppController() : auth = AuthService(), repository = PracticumRepository();

  final AuthService auth;
  final PracticumRepository repository;

  AppUser? user;
  bool busy = true;
  String? error;

  Future<void> initialize() async {
    try {
      user = await auth.restoreUser();
    } catch (exception) {
      error = _messageFor(exception);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await auth.signIn(email, password);
      return true;
    } catch (exception) {
      error = _messageFor(exception);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> registerStudent({
    required String email,
    required String password,
    required String displayName,
    required String studentNumber,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await auth.registerStudent(
        email: email,
        password: password,
        displayName: displayName,
        studentNumber: studentNumber,
      );
      return true;
    } catch (exception) {
      error = _messageFor(exception);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    busy = true;
    notifyListeners();
    await auth.signOut();
    user = null;
    error = null;
    busy = false;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  String _messageFor(Object exception) {
    final raw = exception.toString();
    if (raw.contains('wrong-password') || raw.contains('invalid-credential')) {
      return 'The email or password is incorrect.';
    }
    if (raw.contains('user-not-found')) return 'No account uses that email.';
    if (raw.contains('email-already-in-use')) {
      return 'An account already uses that email address.';
    }
    if (raw.contains('weak-password')) {
      return 'Use a stronger password with at least six characters.';
    }
    return raw.replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
