import 'package:flutter/material.dart';
import '../models/vote.dart';
import '../services/services.dart';

class VoteState extends ChangeNotifier {
  List<Vote>? _voteList;
  Vote? _activeVote;
  String? _selectedOptionInActiveVote;
  bool _isSubmitting = false;

  // Getters
  List<Vote>? get voteList => _voteList;
  Vote? get activeVote => _activeVote;
  String? get selectedOptionInActiveVote => _selectedOptionInActiveVote;
  bool get isSubmitting => _isSubmitting;

  // Setters
  set voteList(List<Vote>? votes) {
    _voteList = votes;
    notifyListeners();
  }

  set activeVote(Vote? vote) {
    _activeVote = vote;
    _selectedOptionInActiveVote =
        null; // Reset selected option when vote changes
    notifyListeners();
  }

  set selectedOptionInActiveVote(String? option) {
    _selectedOptionInActiveVote = option;
    notifyListeners();
  }

  // Methods
  void clearState() {
    _voteList = null;
    _activeVote = null;
    _selectedOptionInActiveVote = null;
    _isSubmitting = false;
    notifyListeners();
  }

  void loadVoteList(BuildContext context) {
    // Load mock data initially
    _voteList = getVoteList();
    notifyListeners();

    // Load real data from Firestore
    getVoteListFromFirestore(context);
  }

  void updateVoteList(List<Vote> newList) {
    _voteList = newList;
    notifyListeners();
  }

  // Method to submit a vote
  Future<bool> submitVote(BuildContext context) async {
    if (_activeVote == null || _selectedOptionInActiveVote == null) {
      return false;
    }

    try {
      _isSubmitting = true;
      notifyListeners();

      markVote(_activeVote!.voteId, _selectedOptionInActiveVote!);

      // Retrieve updated vote data
      if (context.mounted) {
        retrieveMarkedVoteFromFirestore(
            voteId: _activeVote!.voteId, context: context);
      }

      return true;
    } catch (e) {
      debugPrint('Error submitting vote: $e');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
