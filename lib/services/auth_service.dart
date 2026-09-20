import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  Future<AppUser?> restoreUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;
    return _loadProfile(firebaseUser);
  }

  Future<AppUser> signIn(String email, String password) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw StateError('Firebase did not return a signed-in user.');
    }
    return _loadProfile(firebaseUser);
  }

  Future<AppUser> registerStudent({
    required String email,
    required String password,
    required String displayName,
    required String studentNumber,
  }) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw StateError('Firebase did not return the new student account.');
    }
    try {
      await firebaseUser.updateDisplayName(displayName.trim());
      final profile = AppUser(
        uid: firebaseUser.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: UserRole.student,
        studentNumber: studentNumber.trim(),
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set({
            'email': profile.email,
            'displayName': profile.displayName,
            'role': profile.role.value,
            'studentNumber': profile.studentNumber,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return profile;
    } catch (_) {
      await firebaseUser.delete();
      rethrow;
    }
  }

  Future<AppUser> _loadProfile(User firebaseUser) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();
    if (!snapshot.exists) {
      await FirebaseAuth.instance.signOut();
      throw StateError(
        'No user profile was found. Ask an administrator to create the '
        'users/${firebaseUser.uid} record.',
      );
    }
    final profile = AppUser.fromMap(firebaseUser.uid, snapshot.data()!);
    if (!profile.active) {
      await FirebaseAuth.instance.signOut();
      throw StateError('This account has been disabled.');
    }
    return profile;
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
