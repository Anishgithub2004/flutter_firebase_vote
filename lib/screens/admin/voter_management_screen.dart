import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VoterManagementScreen extends StatelessWidget {
  const VoterManagementScreen({super.key});

  Future<void> _verifyUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error verifying user: $e');
    }
  }

  Future<void> _rejectUser(String uid) async {
    try {
      // Store rejected user data
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      await FirebaseFirestore.instance.collection('rejected_users').add({
        ...userDoc.data()!,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Delete the user document
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // Delete the authentication account
      final user = await FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == uid) {
        await user.delete();
      }
    } catch (e) {
      print('Error rejecting user: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voter Management'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('isVerified', isEqualTo: false)
            .where('role', isEqualTo: 'voter')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Text('No pending voter registrations'),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              final uid = users[index].id;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${user['name'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Email: ${user['email'] ?? 'N/A'}'),
                      if (user['phone'] != null)
                        Text('Phone: ${user['phone']}'),
                      if (user['constituency'] != null)
                        Text('Constituency: ${user['constituency']}'),
                      if (user['aadharNo'] != null)
                        Text('Aadhar: ${user['aadharNo']}'),
                      if (user['voterID'] != null)
                        Text('Voter ID: ${user['voterID']}'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _rejectUser(uid),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _verifyUser(uid),
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
