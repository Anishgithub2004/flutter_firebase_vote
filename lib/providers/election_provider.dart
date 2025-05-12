import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Election {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  Election({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory Election.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Election(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
    );
  }
}

class ElectionProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Election> _elections = [];
  bool _isLoading = false;
  String? _error;

  List<Election> get elections => _elections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ElectionProvider() {
    _setupElectionsListener();
  }

  void _setupElectionsListener() {
    _firestore.collection('elections').snapshots().listen(
      (snapshot) {
        _elections = snapshot.docs
            .map((doc) => Election.fromFirestore(doc))
            .where((election) => election.isActive)
            .toList();
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load elections: $error';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> refreshElections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('elections').get();
      _elections = snapshot.docs
          .map((doc) => Election.fromFirestore(doc))
          .where((election) => election.isActive)
          .toList();
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh elections: $e';
    }
    _isLoading = false;
    notifyListeners();
  }
}
