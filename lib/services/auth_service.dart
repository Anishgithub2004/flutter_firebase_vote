import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/candidate.dart';
import '../models/election.dart';
import '../models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  // Sign up with email and password
  Future<User?> signUp(String email, String password,
      {String role = 'voter'}) async {
    try {
      // 1. Create authentication account
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;

      if (user != null) {
        // 2. Create user document in Firestore with the same UID
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
        });

        return user;
      }
      return null;
    } catch (e) {
      print('Error in signUp: $e');
      rethrow;
    }
  }

  // Create user profile
  Future<void> createUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Get user role (admin or voter)
  Future<String?> getUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Election-related methods
  Future<bool> hasVotedInElection(String electionId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final voteDoc = await _firestore
          .collection('votes')
          .where('userId', isEqualTo: userId)
          .where('electionId', isEqualTo: electionId)
          .get();

      return voteDoc.docs.isNotEmpty;
    } catch (e) {
      print('Error checking vote status: $e');
      return false;
    }
  }

  Future<List<Candidate>> getCandidatesForElection(String electionId) async {
    try {
      print('Fetching candidates for election: $electionId');
      final snapshot = await FirebaseFirestore.instance
          .collection('candidates')
          .where('electionId', isEqualTo: electionId)
          .get();

      print('Found ${snapshot.docs.length} candidates');
      print(
          'Candidate documents: ${snapshot.docs.map((doc) => doc.data()).toList()}');

      final candidates =
          snapshot.docs.map((doc) => Candidate.fromFirestore(doc)).toList();
      print('Mapped candidates: ${candidates.map((c) => c.toMap()).toList()}');

      return candidates;
    } catch (e) {
      print('Error fetching candidates: $e');
      return [];
    }
  }

  Future<void> castVote(String electionId, String candidateId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Check if user has already voted
      final hasVoted = await hasVotedInElection(electionId);
      if (hasVoted) throw Exception('You have already voted in this election');

      // Record the vote
      await _firestore.collection('votes').add({
        'userId': userId,
        'electionId': electionId,
        'candidateId': candidateId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update vote count for the candidate
      await _firestore.collection('candidates').doc(candidateId).update({
        'voteCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error casting vote: $e');
      rethrow;
    }
  }

  // Get current user data
  Future<UserModel> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting current user: $e');
      rethrow;
    }
  }

  // Get active elections
  Future<List<Election>> getActiveElections() async {
    try {
      final snapshot = await _firestore
          .collection('elections')
          .where('isActive', isEqualTo: true)
          .where('endDate', isGreaterThan: Timestamp.now())
          .get();

      return snapshot.docs.map((doc) => Election.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error getting active elections: $e');
    }
  }

  // Get pending users for admin verification
  Future<List<UserModel>> getPendingUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('isVerified', isEqualTo: false)
          .where('role', isEqualTo: 'voter')
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting pending users: $e');
      return [];
    }
  }

  // Verify a user
  Future<void> verifyUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error verifying user: $e');
      rethrow;
    }
  }

  // Reject a user
  Future<void> rejectUser(String uid) async {
    try {
      // First get the user's data
      final userDoc = await _firestore.collection('users').doc(uid).get();

      // Store rejected user data in a separate collection for record keeping
      await _firestore.collection('rejected_users').add({
        ...userDoc.data()!,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Delete the user document
      await _firestore.collection('users').doc(uid).delete();

      // Delete the authentication account
      final user = await _auth.currentUser;
      if (user != null && user.uid == uid) {
        await user.delete();
      }
    } catch (e) {
      print('Error rejecting user: $e');
      rethrow;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      // Check if device supports biometrics
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      if (!canAuthenticate) {
        throw PlatformException(
          code: 'NOT_AVAILABLE',
          message: 'Biometric authentication is not available on this device',
        );
      }

      // Check if device has enrolled biometrics
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        throw PlatformException(
          code: 'NOT_ENROLLED',
          message: 'No biometrics enrolled on this device',
        );
      }

      // Authenticate user
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access admin features',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      if (e.code == 'NOT_AVAILABLE') {
        throw Exception(
            'Biometric authentication is not available on this device');
      } else if (e.code == 'NOT_ENROLLED') {
        throw Exception('No biometrics enrolled on this device');
      } else if (e.code == 'PASSCODE_NOT_SET') {
        throw Exception('No passcode set on this device');
      } else if (e.code == 'NOT_PRESENT') {
        throw Exception('No biometric hardware found on this device');
      } else {
        throw Exception('Authentication failed: ${e.message}');
      }
    } catch (e) {
      throw Exception('Authentication failed: $e');
    }
  }

  // Reset a user's vote in an election
  Future<void> resetVote(String electionId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Get the election document
      final electionDoc =
          await _firestore.collection('elections').doc(electionId).get();
      if (!electionDoc.exists) throw Exception('Election not found');

      // Get the vote document
      final voteQuery = await _firestore
          .collection('votes')
          .where('userId', isEqualTo: userId)
          .where('electionId', isEqualTo: electionId)
          .get();

      if (voteQuery.docs.isEmpty)
        throw Exception('No vote found for this election');

      final voteDoc = voteQuery.docs.first;
      final candidateId = voteDoc.data()['candidateId'];

      // Start a transaction to ensure atomic updates
      await _firestore.runTransaction((transaction) async {
        // Remove user ID from votedUserIds array
        transaction.update(
          _firestore.collection('elections').doc(electionId),
          {
            'votedUserIds': FieldValue.arrayRemove([userId]),
            'totalVotes': FieldValue.increment(-1),
          },
        );

        // Decrement candidate's vote count
        transaction.update(
          _firestore.collection('candidates').doc(candidateId),
          {
            'votes': FieldValue.increment(-1),
          },
        );

        // Delete the vote document
        transaction.delete(voteDoc.reference);
      });
    } catch (e) {
      print('Error resetting vote: $e');
      rethrow;
    }
  }
}
