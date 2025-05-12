import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/scheduler.dart';
import '../../models/election.dart';
import '../../models/candidate.dart';
import '../../services/proctoring_service.dart';
import '../../services/biometric_service.dart';
import '../../services/mongodb_service.dart';
import 'dart:async';
import 'face_verification_screen.dart';

class ProctoredVotingScreen extends StatefulWidget {
  final Election election;
  final String sessionId;
  final VoidCallback onSessionEnd;

  const ProctoredVotingScreen({
    super.key,
    required this.election,
    required this.sessionId,
    required this.onSessionEnd,
  });

  @override
  State<ProctoredVotingScreen> createState() => _ProctoredVotingScreenState();
}

class _ProctoredVotingScreenState extends State<ProctoredVotingScreen> {
  bool _isSessionActive = false;
  String? _selectedCandidateId;
  Timer? _sessionTimer;
  Timer? _biometricCheckTimer;
  Timer? _faceDetectionTimer;
  int _remainingTime = 120; // 2 minutes in seconds
  bool _isLoading = false;
  late final ProctoringService _proctoringService;
  int _voteAttempts = 0;
  List<Candidate> _candidates = [];
  bool _isBiometricCheckDue = false;
  bool _isBiometricVerified = false;
  String? _errorMessage;
  bool _isFaceDetected = true;
  late final FirebaseFirestore _firestore;

  @override
  void initState() {
    super.initState();
    _proctoringService = context.read<ProctoringService>();
    _firestore = FirebaseFirestore.instance;
    _checkVoteStatus();
    _loadCandidates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startBiometricVerification();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _biometricCheckTimer?.cancel();
    _faceDetectionTimer?.cancel();
    if (_isSessionActive) {
      _endSession();
    }
    _proctoringService.dispose();
    super.dispose();
  }

  Future<void> _checkVoteStatus() async {
    final user = context.read<User?>();
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      // Check if user has already voted
      final electionDoc = await FirebaseFirestore.instance
          .collection('elections')
          .doc(widget.election.id)
          .get();

      final votedUserIds =
          List<String>.from(electionDoc.data()?['votedUserIds'] ?? []);
      if (votedUserIds.contains(user.uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already voted in this election'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Check vote attempts
      final attemptsDoc = await FirebaseFirestore.instance
          .collection('vote_attempts')
          .doc(user.uid)
          .get();

      if (attemptsDoc.exists) {
        final attempts =
            attemptsDoc.data()?['attempts']?[widget.election.id] ?? 0;
        if (attempts >= 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Maximum vote attempts reached for this election'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.pop(context);
          }
          return;
        }
        setState(() {
          _voteAttempts = attempts;
        });
      }

      _startSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking vote status: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _handleSessionTimeout();
      }
    });
  }

  void _handleSessionTimeout() {
    _sessionTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session timed out. Please try again.')),
    );
    _endSession();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _startBiometricCheckTimer() {
    // Check biometric every 40 seconds
    _biometricCheckTimer = Timer.periodic(const Duration(seconds: 40), (timer) {
      if (_isSessionActive) {
        setState(() {
          _isBiometricCheckDue = true;
        });
        _verifyBiometric();
      }
    });
  }

  Future<void> _verifyBiometric() async {
    if (!_isSessionActive || !_isBiometricCheckDue) return;

    try {
      final biometricService = context.read<BiometricService>();
      final user = context.read<User?>();

      if (user == null) {
        _handleSessionTermination('User not authenticated');
        return;
      }

      final verified = await biometricService.verifyFingerprint(user.uid);
      if (!verified) {
        _handleSessionTermination('Biometric verification failed');
        return;
      }

      setState(() {
        _isBiometricCheckDue = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identity verified successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _handleSessionTermination('Error during verification: $e');
    }
  }

  Future<void> _startBiometricVerification() async {
    try {
      final biometricService = context.read<BiometricService>();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _handleSessionTermination('User not authenticated');
        });
        return;
      }

      final verified = await biometricService.verifyFingerprint(user.uid);
      if (!verified) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _handleSessionTermination('Biometric verification failed');
        });
        return;
      }

      setState(() {
        _isBiometricVerified = true;
      });

      // Start the session after successful biometric verification
      _startSession();
    } catch (e) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _handleSessionTermination('Error during biometric verification: $e');
      });
    }
  }

  Future<void> _startFaceDetection() async {
    try {
      // Start face detection monitoring
      _faceDetectionTimer =
          Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (!_isSessionActive) {
          timer.cancel();
          return;
        }

        try {
          final result = await _proctoringService.checkFaceDetection();
          if (!result['face_detected']) {
            setState(() {
              _isFaceDetected = false;
            });
            _handleSessionTermination(
                'No face detected. Please ensure your face is visible to the camera.');
          } else if (result['multiple_faces']) {
            _handleSessionTermination(
                'Multiple faces detected. Please ensure only you are visible to the camera.');
          } else {
            setState(() {
              _isFaceDetected = true;
            });
          }
        } catch (e) {
          print('Error in face detection: $e');
        }
      });
    } catch (e) {
      print('Error starting face detection: $e');
    }
  }

  Future<void> _startSession() async {
    if (_isLoading || !_isBiometricVerified) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = context.read<User?>();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      setState(() {
        _isSessionActive = true;
        _isLoading = false;
      });

      // Start all timers
      _startTimer();
      _startBiometricCheckTimer();
      _startFaceDetection();

      // Show session monitoring message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proctored session started.\n'
              'Please ensure:\n'
              '1. Your face is visible to the camera\n'
              '2. You are alone in the room\n'
              '3. No other voices are audible'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('Error in _startSession: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _endSession() async {
    if (!mounted || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _proctoringService.stopProctoringSession(widget.sessionId);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isSessionActive = false;
      });

      widget.onSessionEnd();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session ended successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to voter dashboard and remove all previous routes
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/voter',
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ending session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateVoteAttempts() async {
    final user = context.read<User>();
    final attemptRef =
        FirebaseFirestore.instance.collection('vote_attempts').doc(user.uid);

    await attemptRef.set({
      'attempts': {widget.election.id: FieldValue.increment(1)},
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _castVote(String candidateId) async {
    if (!_isSessionActive || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = context.read<User?>();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Verify biometric before casting vote
      final isVerified = await _proctoringService.verifyBiometric(user.uid);
      if (!isVerified) {
        throw Exception('Biometric verification failed');
      }

      // Check face detection
      final faceResult = await _proctoringService.checkFaceDetection();
      if (!faceResult['face_detected'] || faceResult['multiple_faces']) {
        throw Exception('Face verification failed');
      }

      // Cast vote
      await _firestore.collection('elections').doc(widget.election.id).update({
        'votedUserIds': FieldValue.arrayUnion([user.uid]),
      });

      // Record vote attempt
      await _firestore.collection('vote_attempts').doc(user.uid).set({
        'attempts': {
          widget.election.id: FieldValue.increment(1),
        },
      }, SetOptions(merge: true));

      // Stop proctoring session
      await _proctoringService.stopProctoringSession(widget.sessionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote cast successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSessionEnd();
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error casting vote: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error casting vote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCandidates() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print('Loading candidates for election: ${widget.election.id}');

      // First check if election has candidates
      if (widget.election.candidates.isEmpty) {
        print('No candidates found in election object');
        // Try to fetch candidates directly from Firestore
        final candidatesSnapshot = await FirebaseFirestore.instance
            .collection('candidates')
            .where('electionId', isEqualTo: widget.election.id)
            .get();

        print(
            'Fetched ${candidatesSnapshot.docs.length} candidates from Firestore');

        if (candidatesSnapshot.docs.isEmpty) {
          throw Exception('No candidates found for this election');
        }

        final candidates = candidatesSnapshot.docs.map((doc) {
          return Candidate.fromFirestore(doc);
        }).toList();

        setState(() {
          _candidates = candidates;
          _isLoading = false;
        });
        return;
      }

      // If candidates exist in election object, use them
      print(
          'Using candidates from election object: ${widget.election.candidates.length}');
      setState(() {
        _candidates = widget.election.candidates;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading candidates: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _errorMessage = 'Failed to load candidates';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load candidates: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSessionTermination(String reason) {
    _sessionTimer?.cancel();
    _biometricCheckTimer?.cancel();
    _faceDetectionTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session terminated: $reason'),
        backgroundColor: Colors.red,
      ),
    );
    _endSession();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/voter',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBiometricVerified) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verifying biometric authentication...'),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End Session'),
            content: const Text(
                'Are you sure you want to end the proctored session?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('End Session'),
              ),
            ],
          ),
        );
        if (shouldPop == true) {
          await _endSession();
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Proctored Voting'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                final shouldEnd = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('End Session'),
                    content: const Text(
                        'Are you sure you want to end the proctored session?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('End Session'),
                      ),
                    ],
                  ),
                );
                if (shouldEnd == true) {
                  await _endSession();
                }
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Camera preview window
                            Container(
                              height: 150,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    // Camera preview
                                    Center(
                                      child:
                                          _proctoringService.getCameraPreview(),
                                    ),
                                    // Face detection overlay
                                    if (!_isFaceDetected)
                                      Container(
                                        color: Colors.black54,
                                        child: const Center(
                                          child: Text(
                                            'Please ensure your face is visible to the camera',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              'Time Remaining: ${_remainingTime ~/ 60}:${(_remainingTime % 60).toString().padLeft(2, '0')}',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Attempt ${_voteAttempts + 1} of 3',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Select a Candidate:',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            if (_candidates.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No candidates available for this election',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._candidates.map((candidate) {
                                return Card(
                                  child: RadioListTile<String>(
                                    title: Text(candidate.name),
                                    subtitle: Text(candidate.party),
                                    value: candidate.id,
                                    groupValue: _selectedCandidateId,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCandidateId = value;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _selectedCandidateId != null
                                  ? () => _castVote(_selectedCandidateId!)
                                  : null,
                              child: const Text('Cast Vote'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
