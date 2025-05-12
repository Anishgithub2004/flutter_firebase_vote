import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String uid; // Firebase Auth UID
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? constituencyName;
  final String? constituencyNumber;
  final String? aadharNumber;
  final String? panNumber;
  final String? voterIdNumber;
  final int? age;
  final String? gender;
  final String? constituency;
  final String? aadharCardUrl;
  final String? panCardUrl;
  final String? voterIdUrl;
  final String role;
  final bool isVerified;
  final String? profileDp;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final DateTime? dateOfBirth;
  final bool hasFingerprint;
  final Map<String, String> kycDocuments;

  UserModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.constituencyName,
    this.constituencyNumber,
    this.aadharNumber,
    this.panNumber,
    this.voterIdNumber,
    this.age,
    this.gender,
    this.constituency,
    this.aadharCardUrl,
    this.panCardUrl,
    this.voterIdUrl,
    this.role = 'voter',
    this.isVerified = false,
    this.profileDp,
    this.verifiedAt,
    this.createdAt,
    this.dateOfBirth,
    this.hasFingerprint = false,
    this.kycDocuments = const {},
  });

  // Create a copy of the user model with updated fields
  UserModel copyWith({
    String? id,
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? constituencyName,
    String? constituencyNumber,
    String? aadharNumber,
    String? panNumber,
    String? voterIdNumber,
    int? age,
    String? gender,
    String? constituency,
    String? aadharCardUrl,
    String? panCardUrl,
    String? voterIdUrl,
    String? role,
    bool? isVerified,
    String? profileDp,
    DateTime? verifiedAt,
    DateTime? createdAt,
    DateTime? dateOfBirth,
    bool? hasFingerprint,
    Map<String, String>? kycDocuments,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      constituencyName: constituencyName ?? this.constituencyName,
      constituencyNumber: constituencyNumber ?? this.constituencyNumber,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      panNumber: panNumber ?? this.panNumber,
      voterIdNumber: voterIdNumber ?? this.voterIdNumber,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      constituency: constituency ?? this.constituency,
      aadharCardUrl: aadharCardUrl ?? this.aadharCardUrl,
      panCardUrl: panCardUrl ?? this.panCardUrl,
      voterIdUrl: voterIdUrl ?? this.voterIdUrl,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      profileDp: profileDp ?? this.profileDp,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      hasFingerprint: hasFingerprint ?? this.hasFingerprint,
      kycDocuments: kycDocuments ?? this.kycDocuments,
    );
  }

  // Convert Firestore document to UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'],
      constituencyName: data['constituencyName'],
      constituencyNumber: data['constituencyNumber'],
      aadharNumber: data['aadharNumber'],
      panNumber: data['panNumber'],
      voterIdNumber: data['voterIdNumber'],
      age: data['age'],
      gender: data['gender'],
      constituency: data['constituency'],
      aadharCardUrl: data['aadharCardUrl'],
      panCardUrl: data['panCardUrl'],
      voterIdUrl: data['voterIdUrl'],
      role: data['role'] ?? 'voter',
      isVerified: data['isVerified'] ?? false,
      profileDp: data['profileDp'],
      verifiedAt: data['verifiedAt']?.toDate(),
      createdAt: data['createdAt']?.toDate(),
      dateOfBirth: data['dateOfBirth'] is Timestamp
          ? (data['dateOfBirth'] as Timestamp).toDate()
          : DateTime.parse(
              data['dateOfBirth'] ?? DateTime.now().toIso8601String()),
      hasFingerprint: data['hasFingerprint'] ?? false,
      kycDocuments: Map<String, String>.from(data['kycDocuments'] ?? {}),
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'constituencyName': constituencyName,
      'constituencyNumber': constituencyNumber,
      'aadharNumber': aadharNumber,
      'panNumber': panNumber,
      'voterIdNumber': voterIdNumber,
      'age': age,
      'gender': gender,
      'constituency': constituency,
      'aadharCardUrl': aadharCardUrl,
      'panCardUrl': panCardUrl,
      'voterIdUrl': voterIdUrl,
      'role': role,
      'isVerified': isVerified,
      'profileDp': profileDp,
      'verifiedAt': verifiedAt,
      'createdAt': createdAt,
      'dateOfBirth': dateOfBirth,
      'hasFingerprint': hasFingerprint,
      'kycDocuments': kycDocuments,
    };
  }
}
