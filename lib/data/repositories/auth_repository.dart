import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:netvision_ai/data/models/user_models.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream of Firebase auth state changes (used for auto-login).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed-in Firebase user, or null.
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return cred;
  }

  Future<void> recordSuccessfulLogin(String userId) {
    return _firestore.collection('users').doc(userId).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  /// Sign out the current user.
  Future<void> signOut() => _auth.signOut();

  /// Fetch the user's profile document from Firestore.
  /// Returns null if the document does not exist.
  Future<UserModel?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Send a password-reset email.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Update the user's profile in Firestore and return updated UserModel.
  Future<UserModel> updateUserProfile({
    required String userId,
    required String username,
    String? department,
    String? phoneNumber,
    bool? mfaEnabled,
  }) async {
    final updates = <String, dynamic>{
      'username': username.trim(),
      'department': department?.trim(),
      'phoneNumber': phoneNumber?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (mfaEnabled != null) {
      updates['mfaEnabled'] = mfaEnabled;
    }

    await _firestore.collection('users').doc(userId).update(updates);
    final updated = await getUserProfile(userId);
    if (updated == null) {
      throw Exception('Failed to load profile after update.');
    }
    return updated;
  }
}