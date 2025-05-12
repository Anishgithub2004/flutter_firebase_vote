import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/election.dart';
import '../../models/candidate.dart';
import '../../services/biometric_service.dart';
import '../../services/proctoring_service.dart';
import 'proctored_voting_screen.dart';
import 'fingerprint_registration_screen.dart';
import '../../screens/voter_profile_screen.dart';
import '../../services/kyc_service.dart';
import '../../services/auth_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/mongodb_service.dart';
import 'package:intl/intl.dart';

class VoterDashboardScreen extends StatefulWidget {
  const VoterDashboardScreen({Key? key}) : super(key: key);

  @override
  State<VoterDashboardScreen> createState() => _VoterDashboardScreenState();
}

class _VoterDashboardScreenState extends State<VoterDashboardScreen> {
  final BiometricService _biometricService = BiometricService();
  final ProctoringService _proctoringService = ProctoringService();
  final KYCService _kycService = KYCService();
  bool _isInProctoredSession = false;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isEditing = false;
  String? _errorMessage;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aadharNumberController = TextEditingController();
  final _voterIdNumberController = TextEditingController();
  final _panNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _genderController = TextEditingController();
  File? _aadharCardFile;
  File? _voterIdFile;
  File? _panCardFile;
  List<Election> _activeElections = [];

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
    _fetchActiveElections();
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
          _isAuthenticated = false;
        });
        return;
      }

      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _isAuthenticated = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _aadharNumberController.dispose();
    _voterIdNumberController.dispose();
    _panNumberController.dispose();
    _addressController.dispose();
    _dateOfBirthController.dispose();
    _genderController.dispose();
    if (_isInProctoredSession) {
      _proctoringService.stopProctoringSession('');
    }
    super.dispose();
  }

  Future<void> _pickDocument(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        if (pickedFile.path != null) {
          final file = File(pickedFile.path!);
          if (await file.exists()) {
            setState(() {
              switch (type) {
                case 'aadhar':
                  _aadharCardFile = file;
                  break;
                case 'voter':
                  _voterIdFile = file;
                  break;
                case 'pan':
                  _panCardFile = file;
                  break;
              }
            });

            // Save to MongoDB immediately after picking
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                final response = await MongoDBService.uploadKYCDocument(
                  userId: user.uid,
                  documentType: type,
                  filePath: file.path,
                );
                if (response != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Document uploaded successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error uploading document: $e')),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking document: $e')),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? aadharUrl, voterIdUrl, panUrl;

      // Upload KYC documents
      if (_aadharCardFile != null) {
        final response = await _kycService.uploadDocument(
          _aadharCardFile!,
          'aadhar',
          user.uid,
        );
        if (response['success']) {
          aadharUrl = response['fileUrl'];
        }
      }

      if (_voterIdFile != null) {
        final response = await _kycService.uploadDocument(
          _voterIdFile!,
          'voter',
          user.uid,
        );
        if (response['success']) {
          voterIdUrl = response['fileUrl'];
        }
      }

      if (_panCardFile != null) {
        final response = await _kycService.uploadDocument(
          _panCardFile!,
          'pan',
          user.uid,
        );
        if (response['success']) {
          panUrl = response['fileUrl'];
        }
      }

      // Update user profile - exclude timestamp fields
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'aadharNumber': _aadharNumberController.text.trim(),
        'voterIdNumber': _voterIdNumberController.text.trim(),
        'panNumber': _panNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'dateOfBirth': _dateOfBirthController.text.trim(),
        'gender': _genderController.text.trim(),
        'aadharCardUrl': aadharUrl,
        'voterIdUrl': voterIdUrl,
        'panCardUrl': panUrl,
      });

      setState(() {
        _isEditing = false;
        _aadharCardFile = null;
        _voterIdFile = null;
        _panCardFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDocumentUpload(
      String title, String type, File? file, String? url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  file != null
                      ? file.path.split('/').last
                      : url != null
                          ? 'Document uploaded'
                          : 'No document uploaded',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (url != null)
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.black),
                  onPressed: () => _viewDocument(url),
                  tooltip: 'View Document',
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isEditing ? () => _pickDocument(type) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: Icon(
                  file != null || url != null ? Icons.edit : Icons.upload_file,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  file != null || url != null ? 'Change' : 'Upload',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _viewDocument(String url) async {
    try {
      setState(() => _isLoading = true);
      final documentId = url.split('/').last;
      final file = await MongoDBService.getKYCDocument(documentId);

      if (file != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('View Document'),
            content: SizedBox(
              width: double.maxFinite,
              child: Image.file(
                file,
                fit: BoxFit.contain,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error viewing document: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildAuthenticationOverlay() {
    return Center(
      child: SingleChildScrollView(
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
                  'Biometric Verification Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Please verify your biometric to access voting features',
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
                  onPressed: () async {
                    try {
                      final isVerified =
                          await _biometricService.verifyBiometric();
                      if (isVerified) {
                        setState(() {
                          _isAuthenticated = true;
                        });
                      }
                    } catch (e) {
                      setState(() {
                        _errorMessage = e.toString();
                      });
                    }
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Verify Biometric'),
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
      ),
    );
  }

  Widget _buildActiveElections() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Active Elections',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_activeElections.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No active elections available'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeElections.length,
              itemBuilder: (context, index) {
                final election = _activeElections[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(election.title),
                    subtitle: Text(
                      '${DateFormat('MMM dd, yyyy').format(election.startDate)} - ${DateFormat('MMM dd, yyyy').format(election.endDate)}',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _startVotingSession(election),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Vote'),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voter Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VoterProfileScreen(),
                ),
              );
            },
          ),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isAuthenticated
              ? _buildAuthenticationOverlay()
              : _buildActiveElections(),
    );
  }

  Future<bool> _checkVoteEligibility(Election election, String userId) async {
    try {
      // Check if user has already voted
      final electionDoc = await FirebaseFirestore.instance
          .collection('elections')
          .doc(election.id)
          .get();

      final votedUserIds =
          List<String>.from(electionDoc.data()?['votedUserIds'] ?? []);
      if (votedUserIds.contains(userId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already voted in this election'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Check vote attempts
      final attemptsDoc = await FirebaseFirestore.instance
          .collection('vote_attempts')
          .doc(userId)
          .get();

      if (attemptsDoc.exists) {
        final attempts = attemptsDoc.data()?['attempts']?[election.id] ?? 0;
        if (attempts >= 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Maximum vote attempts reached for this election'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking vote eligibility: $e')),
        );
      }
      return false;
    }
  }

  Future<bool> _checkKYCDocuments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final result = await MongoDBService.checkKYCDocuments(user.uid);
      print('KYC check result: $result');

      if (!result['success']) {
        print('Error checking KYC documents: ${result['error']}');
        return false;
      }

      final hasAllDocuments = result['hasAllDocuments'] ?? false;
      final documents = result['documents'] ?? {};

      print(
          'Document check results - Aadhar: ${documents['aadhar']}, PAN: ${documents['pan']}, Voter ID: ${documents['voterId']}');

      if (!hasAllDocuments) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please upload all required KYC documents before voting'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pushNamed(context, '/voter-profile');
        }
      }

      return hasAllDocuments;
    } catch (e) {
      print('Error checking KYC documents: $e');
      return false;
    }
  }

  Future<void> _startVotingSession(Election election) async {
    try {
      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Check vote eligibility
      final isEligible = await _checkVoteEligibility(election, user.uid);
      if (!isEligible) {
        setState(() => _isLoading = false);
        return;
      }

      // Start proctoring session
      final sessionId = await _proctoringService.startProctoringSession(
          user.uid, election.id);

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/voter/proctored-voting',
          arguments: {
            'election': election,
            'sessionId': sessionId,
            'onSessionEnd': () {
              setState(() {
                _isInProctoredSession = false;
              });
            },
          },
        );
      }
    } catch (e) {
      print('Error starting voting session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting voting session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchActiveElections() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final now = DateTime.now();
      // Simplified query to avoid index requirements
      final electionsSnapshot = await FirebaseFirestore.instance
          .collection('elections')
          .where('isActive', isEqualTo: true)
          .get();

      final elections = electionsSnapshot.docs.map((doc) {
        return Election.fromFirestore(doc);
      }).toList();

      // Filter elections that are currently active
      final activeElections = elections.where((election) {
        final isStarted = election.startDate.isBefore(now) ||
            election.startDate.isAtSameMomentAs(now);
        final isNotEnded = election.endDate.isAfter(now);
        return isStarted && isNotEnded;
      }).toList();

      setState(() {
        _activeElections = activeElections;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching active elections: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching active elections: $e';
      });
    }
  }
}
