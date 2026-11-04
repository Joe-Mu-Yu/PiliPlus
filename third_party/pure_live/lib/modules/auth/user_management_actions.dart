import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_live/modules/auth/utils/firebase_manager.dart';

/// Cloud mutations requested by the management UI. Presentation and route
/// lifetime are owned by the caller, not by the Firestore operation.
class UserManagementActions {
  const UserManagementActions();

  Future<void> deleteUser(String uid, {required bool deletePermission}) async {
    if (deletePermission) {
      await FirebaseManager.getInstance().firestore.collection('permissions').doc(uid).delete();
    }
    await FirebaseManager.getInstance().firestore.collection('users').doc(uid).delete();
  }

  Future<void> promote(String uid, String email) => FirebaseManager.getInstance().firestore.collection('permissions').doc(uid).set({
    'canUpload': true,
    'role': 'manager',
    'email': email,
  });

  Future<void> demote(String uid) => FirebaseManager.getInstance().firestore.collection('permissions').doc(uid).delete();

  Future<void> setUpload(String uid, bool allowed) =>
      FirebaseManager.getInstance().firestore.collection('users').doc(uid).set({'canUpload': allowed}, SetOptions(merge: true));
}
