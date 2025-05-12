import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import '../../providers/auth_provider.dart';
import '../../providers/election_provider.dart' as election_provider;
import 'election_management_screen.dart';
import 'voter_management_screen.dart';
import 'fingerprint_registration_screen.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/election.dart';
import 'election_results_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hasValidBiometric = await _biometricService.hasValidBiometric();
      if (!hasValidBiometric) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please register your biometric data first';
        });
        return;
      }

      final isAuthenticated = await _biometricService.verifyBiometric();
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isAuthenticated = await _biometricService.verifyBiometric();
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });

      if (_isAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication successful!')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _verifyVoter(BuildContext context, String userId) async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please authenticate first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'isVerified': true});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voter verified successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying voter: $e')),
      );
    }
  }

  Widget _buildProtectedAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService().signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.manage_accounts),
                text: 'Manage Elections',
              ),
              Tab(
                icon: Icon(Icons.how_to_vote),
                text: 'Active Elections',
              ),
              Tab(
                icon: Icon(Icons.bar_chart),
                text: 'Past Elections',
              ),
              Tab(
                icon: Icon(Icons.pending_actions),
                text: 'Pending Verifications',
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_isAuthenticated
                ? _buildAuthenticationOverlay()
                : TabBarView(
                    children: [
                      _buildElectionManagementTab(),
                      _buildActiveElectionsTab(),
                      _buildResultsTab(),
                      _buildPendingVerificationsTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildAuthenticationOverlay() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fingerprint,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              const Text(
                'Biometric Authentication Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Please authenticate to access admin features',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Authenticate'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveElectionsTab() {
    if (!_isAuthenticated) {
      return _buildAuthenticationOverlay();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('elections')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeElections = snapshot.data!.docs;

        if (activeElections.isEmpty) {
          return const Center(
            child: Text('No active elections'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeElections.length,
          itemBuilder: (context, index) {
            final election = activeElections[index];
            final electionData = election.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const Icon(Icons.how_to_vote, color: Colors.blue),
                title: Text(
                  electionData['title'] ?? 'Untitled Election',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start: ${(electionData['startDate'] as Timestamp).toDate().toLocal().toString().split(' ')[0]}',
                    ),
                    Text(
                      'End: ${(electionData['endDate'] as Timestamp).toDate().toLocal().toString().split(' ')[0]}',
                    ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ElectionResultsScreen(
                        election: Election(
                          id: election.id,
                          title: electionData['title'] ?? '',
                          description: electionData['description'] ?? '',
                          startDate:
                              (electionData['startDate'] as Timestamp).toDate(),
                          endDate:
                              (electionData['endDate'] as Timestamp).toDate(),
                          isActive: electionData['isActive'] ?? false,
                          votedUserIds:
                              (electionData['votedUserIds'] as List<dynamic>?)
                                      ?.map((id) => id as String)
                                      .toList() ??
                                  [],
                          candidates: [],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingVerificationsTab() {
    if (!_isAuthenticated) {
      return _buildAuthenticationOverlay();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'voter')
          .where('isVerified', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final pendingVoters = snapshot.data!.docs;

        if (pendingVoters.isEmpty) {
          return const Center(
            child: Text('No pending voter verifications'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingVoters.length,
          itemBuilder: (context, index) {
            final voter = pendingVoters[index];
            final voterData = voter.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            voterData['name'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Email: ${voterData['email'] ?? 'N/A'}'),
                    if (voterData['aadharNo'] != null)
                      Text('Aadhar: ${voterData['aadharNo']}'),
                    if (voterData['voterID'] != null)
                      Text('Voter ID: ${voterData['voterID']}'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _verifyVoter(context, voter.id),
                          icon: const Icon(Icons.verified_user),
                          label: const Text('Verify Voter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
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
    );
  }

  Widget _buildResultsTab() {
    if (!_isAuthenticated) {
      return _buildAuthenticationOverlay();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('elections')
          .where('isActive', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final completedElections = snapshot.data!.docs;

        // Sort elections by endDate in memory
        completedElections.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aEndDate = (aData['endDate'] as Timestamp).toDate();
          final bEndDate = (bData['endDate'] as Timestamp).toDate();
          return bEndDate.compareTo(aEndDate); // Descending order
        });

        if (completedElections.isEmpty) {
          return const Center(
            child: Text('No completed elections'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedElections.length,
          itemBuilder: (context, index) {
            final election = completedElections[index];
            final electionData = election.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.blue),
                title: Text(
                  electionData['title'] ?? 'Untitled Election',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Ended: ${(electionData['endDate'] as Timestamp).toDate().toLocal().toString().split(' ')[0]}',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ElectionResultsScreen(
                        election: Election(
                          id: election.id,
                          title: electionData['title'] ?? '',
                          description: electionData['description'] ?? '',
                          startDate:
                              (electionData['startDate'] as Timestamp).toDate(),
                          endDate:
                              (electionData['endDate'] as Timestamp).toDate(),
                          isActive: electionData['isActive'] ?? false,
                          votedUserIds:
                              (electionData['votedUserIds'] as List<dynamic>?)
                                      ?.map((id) => id as String)
                                      .toList() ??
                                  [],
                          candidates: [],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildElectionManagementTab() {
    if (!_isAuthenticated) {
      return _buildAuthenticationOverlay();
    }

    return const ElectionManagementScreen();
  }
}
