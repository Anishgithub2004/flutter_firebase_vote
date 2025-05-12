import 'package:cloud_firestore/cloud_firestore.dart';
import 'candidate.dart';

class Election {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final List<String> votedUserIds;
  List<Candidate> candidates;

  Election({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.votedUserIds,
    required this.candidates,
  });

  // Factory constructor for creating Election from Firestore DocumentSnapshot
  factory Election.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Election(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      candidates: (data['candidates'] as List<dynamic>?)
              ?.map((c) => Candidate.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      votedUserIds: (data['votedUserIds'] as List<dynamic>?)
              ?.map((id) => id as String)
              .toList() ??
          [],
      isActive: data['isActive'] ?? false,
    );
  }

  // Factory constructor for creating Election from Map
  factory Election.fromMap(Map<String, dynamic> map) {
    return Election(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : DateTime.now(),
      candidates: (map['candidates'] as List<dynamic>?)
              ?.map((c) => Candidate.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      votedUserIds: (map['votedUserIds'] as List<dynamic>?)
              ?.map((id) => id as String)
              .toList() ??
          [],
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  // Convert Election to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'candidates': candidates.map((c) => c.toMap()).toList(),
      'votedUserIds': votedUserIds,
      'isActive': isActive,
    };
  }

  // Helper method to check if election is currently active
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  // Helper method to check if a user has voted
  bool hasUserVoted(String userId) {
    return votedUserIds.contains(userId);
  }

  // Helper method to get candidate by ID
  Candidate? getCandidateById(String candidateId) {
    try {
      return candidates.firstWhere((c) => c.id == candidateId);
    } catch (e) {
      return null;
    }
  }
}
