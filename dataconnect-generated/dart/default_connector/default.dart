library;

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:convert';

class DefaultConnector {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static FirebaseFirestore get instance => _firestore;

  // Helper method to get a collection reference
  static CollectionReference collection(String path) {
    return _firestore.collection(path);
  }

  // Helper method to get a document reference
  static DocumentReference document(String path) {
    return _firestore.doc(path);
  }
}
