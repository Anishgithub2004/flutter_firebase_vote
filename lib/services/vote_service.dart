import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vote.dart';

class VoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _votesCollection = 'votes';
  final String _votingHistoryCollection = 'voting_history';

  // Create a new vote
  Future<String?> createVote(Vote vote) async {
    try {
      DocumentReference docRef =
          await _firestore.collection(_votesCollection).add(vote.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating vote: $e');
      return null;
    }
  }

  // Get all votes
  Stream<List<Vote>> getVotes() {
    return _firestore.collection(_votesCollection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Vote.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  // Get a specific vote
  Future<Vote?> getVote(String voteId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection(_votesCollection).doc(voteId).get();

      if (doc.exists) {
        return Vote.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting vote: $e');
      return null;
    }
  }

  // Submit a vote
  Future<bool> submitVote(String voteId, String option, String userId) async {
    try {
      // Check if user has already voted
      bool hasVoted = await hasUserVoted(voteId, userId);
      if (hasVoted) {
        return false;
      }

      // Update vote count
      await _firestore
          .collection(_votesCollection)
          .doc(voteId)
          .update({option: FieldValue.increment(1)});

      // Record voting history
      await _firestore.collection(_votingHistoryCollection).add({
        'userId': userId,
        'voteId': voteId,
        'option': option,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error submitting vote: $e');
      return false;
    }
  }

  // Check if user has already voted
  Future<bool> hasUserVoted(String voteId, String userId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection(_votingHistoryCollection)
          .where('voteId', isEqualTo: voteId)
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking voting history: $e');
      return true; // Return true to prevent voting on error
    }
  }

  // Get voting results for a specific vote
  Stream<Vote?> getVoteResults(String voteId) {
    return _firestore
        .collection(_votesCollection)
        .doc(voteId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return Vote.fromFirestore(doc.id, doc.data()!);
      }
      return null;
    });
  }

  // Delete a vote (admin only)
  Future<bool> deleteVote(String voteId) async {
    try {
      await _firestore.collection(_votesCollection).doc(voteId).delete();
      return true;
    } catch (e) {
      print('Error deleting vote: $e');
      return false;
    }
  }
}
