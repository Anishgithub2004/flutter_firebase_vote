/// Created by Mahmud Ahsan
/// https://github.com/mahmudahsan
library;
import 'package:flutter/material.dart';
import 'package:flutter_firebase_vote/services/services.dart';
import 'package:flutter_firebase_vote/state/vote.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'dart:ui';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _controller;
  bool _isHoveredVoter = false;
  bool _isHoveredSignup = false;
  bool _isHoveredAdmin = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    // Optimize Provider usage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && FirebaseAuth.instance.currentUser != null) {
        final voteState = Provider.of<VoteState>(context, listen: false);
        voteState.clearState();
        voteState.loadVoteList(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Step getStep({
    required String title,
    required Widget child,
    required bool isActive,
  }) {
    return Step(
      title: Text(title),
      content: child,
      isActive: isActive,
    );
  }

  void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> markMyVote(VoteState voteState) async {
    if (await voteState.submitVote(context)) {
      if (mounted) {
        showSnackBar(context, 'Vote submitted successfully!');
      }
    } else {
      if (mounted) {
        showSnackBar(context, 'Failed to submit vote. Please try again.');
      }
    }
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
              // Animated background particles
              ...List.generate(20, (index) => _buildParticle(index)),
              
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            // Animated Logo
                            _buildAnimatedLogo(),
                            const SizedBox(height: 24),
                            // Animated Title
                            _buildAnimatedTitle(),
                            const SizedBox(height: 16),
                            // Subtitle with shimmer effect
                            Shimmer(
                              duration: const Duration(seconds: 3),
                              interval: const Duration(seconds: 5),
                              color: Colors.white,
                              colorOpacity: 0.5,
                              child: Text(
                                'Secure Digital Voting Platform',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 60),
                            
                            // Main Card with glassmorphism effect
                            Container(
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
                                  child: Container(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Welcome',
                                          style: GoogleFonts.poppins(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ).animate()
                                          .fadeIn(duration: const Duration(milliseconds: 600))
                                          .scale(delay: const Duration(milliseconds: 200)),
                                        const SizedBox(height: 24),
                                        _buildAnimatedButton(
                                          'Login as Voter',
                                          Icons.how_to_vote,
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const LoginScreen(),
                                            ),
                                          ),
                                          _isHoveredVoter,
                                          (value) => setState(() => _isHoveredVoter = value),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildAnimatedButton(
                                          'Create Account',
                                          Icons.person_add,
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const SignupScreen(),
                                            ),
                                          ),
                                          _isHoveredSignup,
                                          (value) => setState(() => _isHoveredSignup = value),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildAnimatedAdminButton(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ).animate()
                              .fadeIn(duration: const Duration(milliseconds: 600))
                              .slideY(begin: 0.3, delay: const Duration(milliseconds: 600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Animated footer
                  _buildAnimatedFooter(),
                ],
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
    final initialPosition = random.nextDouble() * MediaQuery.of(context).size.width;
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
      ).animate(
        onComplete: (controller) => controller.repeat(),
      ).moveY(
        begin: -size,
        end: MediaQuery.of(context).size.height + size,
        duration: duration,
        curve: Curves.linear,
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 0.1,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: _controller.value * 10,
                ),
              ],
            ),
            child: Icon(
              Icons.how_to_vote,
              size: 80,
              color: Colors.white,
            ),
          ),
        );
      },
    ).animate()
      .fadeIn(duration: const Duration(milliseconds: 600))
      .scale(delay: const Duration(milliseconds: 200));
  }

  Widget _buildAnimatedTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: 'E-VOTEX'.split('').map((letter) {
        return Text(
          letter,
          style: GoogleFonts.montserrat(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ).animate()
          .fadeIn(duration: const Duration(milliseconds: 600))
          .scale(delay: Duration(milliseconds: 200 * 'E-VOTEX'.indexOf(letter)))
          .shimmer(
            duration: const Duration(milliseconds: 1200), 
            delay: const Duration(milliseconds: 800)
          );
      }).toList(),
    );
  }

  Widget _buildAnimatedButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
    bool isHovered,
    Function(bool) onHover,
  ) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isHovered ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate()
        .fadeIn(duration: const Duration(milliseconds: 600))
        .slideX(
          begin: -0.1,
          end: 0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        ),
    );
  }

  Widget _buildAnimatedAdminButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveredAdmin = true),
      onExit: (_) => setState(() => _isHoveredAdmin = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: _isHoveredAdmin ? 1.05 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
          ),
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(isAdminLogin: true),
              ),
            ),
            icon: Icon(
              Icons.admin_panel_settings,
              color: _isHoveredAdmin ? Colors.white : Colors.white70,
            ),
            label: Text(
              'Admin Login',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isHoveredAdmin ? Colors.white : Colors.white70,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        '© 2024 E-VOTEX. All rights reserved.',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    ).animate()
      .fadeIn(duration: const Duration(milliseconds: 600))
      .slideY(begin: 0.3, delay: const Duration(milliseconds: 800));
  }
}

class VoteListWidget extends StatelessWidget {
  final VoteState voteState;

  const VoteListWidget({
    super.key,
    required this.voteState,
  });

  @override
  Widget build(BuildContext context) {
    final voteList = voteState.voteList;
    if (voteList == null || voteList.isEmpty) {
      return const Center(
        child: Text('No votes available'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: voteList.length,
      itemBuilder: (context, index) {
        final vote = voteList[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(vote.voteTitle),
            subtitle: Text('${vote.options.length} options available'),
            selected: vote.voteId == voteState.activeVote?.voteId,
            onTap: () => voteState.activeVote = vote,
          ),
        );
      },
    );
  }
}

class VoteWidget extends StatelessWidget {
  final VoteState voteState;

  const VoteWidget({
    super.key,
    required this.voteState,
  });

  @override
  Widget build(BuildContext context) {
    final activeVote = voteState.activeVote;
    if (activeVote == null) {
      return const Center(
        child: Text('Please select a vote first'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeVote.voteTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...activeVote.options.map((option) {
          final optionName = option.keys.first;
          final votes = option.values.first;
          return RadioListTile<String>(
            title: Text(optionName),
            subtitle: Text('Current votes: $votes'),
            value: optionName,
            groupValue: voteState.selectedOptionInActiveVote,
            onChanged: (value) => voteState.selectedOptionInActiveVote = value,
          );
        }).toList(),
      ],
    );
  }
}
