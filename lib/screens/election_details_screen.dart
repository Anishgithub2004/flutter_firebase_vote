import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../models/election.dart';
import '../models/candidate.dart';
import 'dart:math';

class ElectionDetailsScreen extends StatefulWidget {
  final Election election;

  const ElectionDetailsScreen({
    super.key,
    required this.election,
  });

  @override
  _ElectionDetailsScreenState createState() => _ElectionDetailsScreenState();
}

class _ElectionDetailsScreenState extends State<ElectionDetailsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _hasVoted = false;
  String? _selectedCandidateId;
  List<Candidate> _candidates = [];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _loadElectionDetails();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadElectionDetails() async {
    setState(() => _isLoading = true);
    try {
      final hasVoted =
          await _authService.hasVotedInElection(widget.election.id);
      final candidates =
          await _authService.getCandidatesForElection(widget.election.id);
      setState(() {
        _hasVoted = hasVoted;
        _candidates = candidates;
      });
    } catch (e) {
      _showError('Error loading election details: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _castVote() async {
    if (_selectedCandidateId == null) {
      _showError('Please select a candidate');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Your Vote',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please review your selection:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.withOpacity(0.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Election:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    widget.election.title,
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selected Candidate:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _candidates
                        .firstWhere((c) => c.id == _selectedCandidateId)
                        .name,
                    style: GoogleFonts.poppins(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Important:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• This action cannot be undone\n• You can only vote once in this election\n• Your vote will be securely recorded',
              style: GoogleFonts.poppins(
                color: Colors.red[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6200EA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Confirm Vote',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _authService.castVote(widget.election.id, _selectedCandidateId!);
      _showSuccess('Your vote has been successfully recorded!');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vote Recorded',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your vote has been securely recorded. Thank you for participating in this election.',
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.withOpacity(0.1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your vote is anonymous and has been encrypted.',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to dashboard
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6200EA),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Return to Dashboard',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      setState(() => _hasVoted = true);
    } catch (e) {
      _showError('Error casting vote: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              const Color(0xFF2980B9),
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ...List.generate(20, (index) => _buildParticle(index)),
              SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text(
                          'Election Details',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _loadCandidates,
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600)),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white.withOpacity(0.15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.election.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.election.description ??
                                    'No description available',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 20, color: Colors.white70),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ends on ${_formatDate(widget.election.endDate)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600))
                        .slideY(begin: 0.3),
                    const SizedBox(height: 32),
                    Text(
                      'Candidates',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600))
                        .slideY(begin: 0.3),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                    else if (_candidates.isEmpty)
                      Center(
                        child: Text(
                          'No candidates available',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = _candidates[index];
                          final List<List<Color>> gradients = [
                            [
                              const Color(0xFF6200EA),
                              const Color(0xFF9C27B0)
                            ], // Purple to Pink
                            [
                              const Color(0xFF1E88E5),
                              const Color(0xFF00BCD4)
                            ], // Blue to Cyan
                            [
                              const Color(0xFF43A047),
                              const Color(0xFF8BC34A)
                            ], // Green
                            [
                              const Color(0xFFE53935),
                              const Color(0xFFFF5722)
                            ], // Red to Orange
                            [
                              const Color(0xFF3949AB),
                              const Color(0xFF2196F3)
                            ], // Deep Blue
                          ];

                          return Shimmer(
                            duration: const Duration(seconds: 3),
                            interval: const Duration(seconds: 5),
                            color: Colors.white,
                            colorOpacity: 0.3,
                            enabled: true,
                            direction: const ShimmerDirection.fromLTRB(),
                            child: GestureDetector(
                              onTap: _hasVoted
                                  ? null
                                  : () {
                                      setState(() =>
                                          _selectedCandidateId = candidate.id);
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 24),
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: _selectedCandidateId == candidate.id
                                        ? [Colors.white, Colors.white70]
                                        : gradients[index % gradients.length],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_selectedCandidateId ==
                                                  candidate.id
                                              ? Colors.white
                                              : gradients[
                                                  index % gradients.length][0])
                                          .withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _selectedCandidateId ==
                                                  candidate.id
                                              ? const Color(0xFF6200EA)
                                              : Colors.white.withOpacity(0.2),
                                          border: Border.all(
                                            color: _selectedCandidateId ==
                                                    candidate.id
                                                ? const Color(0xFF6200EA)
                                                : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            candidate.name[0].toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              candidate.name,
                                              style: GoogleFonts.poppins(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedCandidateId ==
                                                        candidate.id
                                                    ? const Color(0xFF6200EA)
                                                    : Colors.white,
                                              ),
                                            ),
                                            Text(
                                              candidate.party,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                color: _selectedCandidateId ==
                                                        candidate.id
                                                    ? const Color(0xFF6200EA)
                                                        .withOpacity(0.8)
                                                    : Colors.white
                                                        .withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!_hasVoted)
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _selectedCandidateId ==
                                                    candidate.id
                                                ? const Color(0xFF6200EA)
                                                : Colors.white.withOpacity(0.2),
                                            border: Border.all(
                                              color: _selectedCandidateId ==
                                                      candidate.id
                                                  ? const Color(0xFF6200EA)
                                                  : Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: _selectedCandidateId ==
                                                  candidate.id
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 20,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                  duration: const Duration(milliseconds: 600))
                              .slideX(
                                  begin: 0.3,
                                  delay: Duration(milliseconds: index * 100));
                        },
                      ),
                    const SizedBox(height: 32),
                    if (!_hasVoted)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _selectedCandidateId == null || _isSubmitting
                                  ? null
                                  : _submitVote,
                          style: AppTheme.elevatedButtonStyle.copyWith(
                            backgroundColor:
                                MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.grey;
                              }
                              return AppTheme.secondaryColor;
                            }),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Submit Vote'),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: const Duration(milliseconds: 600))
                          .slideY(begin: 0.3),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticle(int index) {
    final random = Random();
    final size = random.nextDouble() * 10 + 5;
    final initialPosition =
        random.nextDouble() * MediaQuery.of(context).size.width;
    final duration = Duration(seconds: random.nextInt(10) + 10);

    return Positioned(
      left: initialPosition,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
      )
          .animate(
            onComplete: (controller) => controller.repeat(),
          )
          .moveY(
            begin: -size,
            end: MediaQuery.of(context).size.height + size,
            duration: duration,
            curve: Curves.linear,
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isSubmitting = false;

  Future<void> _submitVote() async {
    setState(() => _isSubmitting = true);
    try {
      await _castVote();
    } catch (e) {
      _showError('Error submitting vote: ${e.toString()}');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _loadCandidates() async {
    await _loadElectionDetails();
  }
}
