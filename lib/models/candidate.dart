import 'package:cloud_firestore/cloud_firestore.dart';

class Candidate {
  final String id;
  final String name;
  final String party;
  final String? photoUrl;
  final String? manifesto;
  final String electionId;
  int votes;

  Candidate({
    required this.id,
    required this.name,
    required this.party,
    this.photoUrl,
    this.manifesto,
    required this.electionId,
    this.votes = 0,
  });

  // Factory constructor for creating Candidate from Firestore DocumentSnapshot
  factory Candidate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Candidate(
      id: doc.id,
      name: data['name'] ?? '',
      party: data['party'] ?? '',
      photoUrl: data['photoUrl'],
      manifesto: data['manifesto'],
      electionId: data['electionId'] ?? '',
      votes: data['votes'] ?? 0,
    );
  }

  // Factory constructor for creating Candidate from Map
  factory Candidate.fromMap(Map<String, dynamic> map) {
    return Candidate(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      party: map['party'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      manifesto: map['manifesto'] as String?,
      electionId: map['electionId'] as String? ?? '',
      votes: map['votes'] as int? ?? 0,
    );
  }

  // Convert Candidate to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'party': party,
      'photoUrl': photoUrl,
      'manifesto': manifesto,
      'electionId': electionId,
      'votes': votes,
    };
  }

  // Helper method to check if candidate has a photo
  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  // Helper method to check if candidate has a manifesto
  bool get hasManifesto => manifesto != null && manifesto!.isNotEmpty;

  // Helper method to increment votes
  Candidate incrementVotes() {
    return Candidate(
      id: id,
      name: name,
      party: party,
      photoUrl: photoUrl,
      manifesto: manifesto,
      electionId: electionId,
      votes: votes + 1,
    );
  }
}
