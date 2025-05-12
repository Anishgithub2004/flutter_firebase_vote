import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import 'dart:math';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _constituencyController = TextEditingController();
  final _aadharController = TextEditingController();
  final _voterIdController = TextEditingController();
  final _dobController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isHoveredSignup = false;
  DateTime? _selectedDate;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _constituencyController.dispose();
    _aadharController.dispose();
    _voterIdController.dispose();
    _dobController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final constituency = _constituencyController.text.trim();
      final aadharNo = _aadharController.text.trim();
      final voterId = _voterIdController.text.trim();

      // Validate Aadhar number (12 digits)
      if (aadharNo.length != 12 || !RegExp(r'^\d+$').hasMatch(aadharNo)) {
        throw 'Please enter a valid 12-digit Aadhar number';
      }

      // Validate Voter ID format
      if (!RegExp(r'^[A-Z]{3}[0-9]{7}$').hasMatch(voterId)) {
        throw 'Please enter a valid Voter ID (e.g., ABC1234567)';
      }

      final User? user = await _authService.signUp(email, password);

      if (user != null && mounted) {
        final userModel = UserModel(
          id: user.uid,
          uid: user.uid,
          name: name,
          email: email,
          phone: phone,
          constituency: constituency,
          aadharNumber: aadharNo,
          voterIdNumber: voterId,
          dateOfBirth: _selectedDate,
          role: 'voter',
          isVerified: false,
          createdAt: DateTime.now(),
        );

        await _authService.createUserProfile(userModel);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Registration successful! Please wait for admin verification.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/voter');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600)),
                    const SizedBox(height: 20),
                    Center(
                      child: AnimatedBuilder(
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
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: _controller.value * 10,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.how_to_vote,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600)),
                    const SizedBox(height: 20),
                    Center(
                      child: Shimmer(
                        duration: const Duration(seconds: 3),
                        interval: const Duration(seconds: 5),
                        color: Colors.white,
                        colorOpacity: 0.5,
                        child: Text(
                          'Voter Registration',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
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
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Full Name',
                                      prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your name'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _emailController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Email',
                                      prefixIcon: const Icon(
                                          Icons.email_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true)
                                        return 'Please enter your email';
                                      if (!value!.contains('@'))
                                        return 'Please enter a valid email';
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _phoneController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Phone Number',
                                      prefixIcon: const Icon(
                                          Icons.phone_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true)
                                        return 'Please enter your phone number';
                                      if (!RegExp(r'^[0-9]{10}$')
                                          .hasMatch(value!)) {
                                        return 'Please enter a valid 10-digit phone number';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _constituencyController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Constituency',
                                      prefixIcon: const Icon(
                                          Icons.location_on_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your constituency'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _aadharController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Aadhar Number',
                                      prefixIcon: const Icon(
                                          Icons.badge_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    maxLength: 12,
                                    validator: (value) {
                                      if (value?.isEmpty ?? true)
                                        return 'Please enter your Aadhar number';
                                      if (value!.length != 12 ||
                                          !RegExp(r'^\d+$').hasMatch(value)) {
                                        return 'Please enter a valid 12-digit Aadhar number';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _voterIdController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Voter ID',
                                      prefixIcon: const Icon(
                                          Icons.card_membership_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true)
                                        return 'Please enter your Voter ID';
                                      if (!RegExp(r'^[A-Z]{3}[0-9]{7}$')
                                          .hasMatch(value!)) {
                                        return 'Please enter a valid Voter ID (e.g., ABC1234567)';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _dobController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Date of Birth',
                                      prefixIcon: const Icon(
                                          Icons.calendar_today_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    readOnly: true,
                                    onTap: () => _selectDate(context),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please select your date of birth'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(Icons.lock_outline,
                                          color: Colors.white70),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.white70,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true)
                                        return 'Please enter a password';
                                      if (value!.length < 6)
                                        return 'Password must be at least 6 characters';
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Confirm Password',
                                      prefixIcon: const Icon(Icons.lock_outline,
                                          color: Colors.white70),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.white70,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword),
                                      ),
                                    ),
                                    obscureText: _obscureConfirmPassword,
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) {
                                      if (value?.isEmpty ?? true)
                                        return 'Please confirm your password';
                                      if (value != _passwordController.text)
                                        return 'Passwords do not match';
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _signup,
                                      style: AppTheme.elevatedButtonStyle,
                                      child: _isLoading
                                          ? const CircularProgressIndicator(
                                              color: Colors.white)
                                          : const Text('Register as Voter'),
                                    ),
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Already have an account? Login',
                                      style: GoogleFonts.poppins(
                                          color: Colors.white70),
                                    ),
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600))
                        .slideY(
                            begin: 0.3,
                            delay: const Duration(milliseconds: 200)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
