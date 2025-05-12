import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import 'dart:ui';
import 'dart:math';
import '../services/user_service.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  _AdminProfileScreenState createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isLoading = false;
  UserModel? _currentUser;

  // Controllers for form fields
  final _usernameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileNoController = TextEditingController();
  final _aadharNoController = TextEditingController();
  final _panCardNoController = TextEditingController();
  final _voterIdNoController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedGender;
  final _constituencyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      await for (final user in _userService.getCurrentUserProfile()) {
        if (user != null) {
          setState(() {
            _currentUser = user;
            _usernameController.text = user.name;
            _addressController.text = user.address ?? '';
            _mobileNoController.text = user.phone;
            _aadharNoController.text = user.aadharCardUrl ?? '';
            _panCardNoController.text = user.panCardUrl ?? '';
            _voterIdNoController.text = user.voterIdUrl ?? '';
            _ageController.text = user.age?.toString() ?? '';
            _selectedGender = user.gender;
            _constituencyController.text = user.constituency ?? '';
          });
          break; // Exit the stream after getting the first value
        }
      }
    } catch (e) {
      _showError('Error loading profile: ${e.toString()}');
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

  void _startEdit() {
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
    _loadUserProfile(); // Reset form fields to original values
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _addressController.dispose();
    _mobileNoController.dispose();
    _aadharNoController.dispose();
    _panCardNoController.dispose();
    _voterIdNoController.dispose();
    _ageController.dispose();
    _constituencyController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        final success = await _userService.updateProfileFields(
          username: _usernameController.text,
          address: _addressController.text,
          mobileNo: _mobileNoController.text,
          aadharNo: _aadharNoController.text,
          panCardNo: _panCardNoController.text,
          voterIdNo: _voterIdNoController.text,
          age: int.tryParse(_ageController.text),
          gender: _selectedGender,
          constituency: _constituencyController.text,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          setState(() => _isEditing = false);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      } catch (e) {
        _showError('Error updating profile: ${e.toString()}');
      } finally {
        setState(() => _isLoading = false);
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
                          'Admin Profile',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            if (mounted) {
                              Navigator.of(context).pushReplacementNamed('/');
                            }
                          },
                        ),
                      ],
                    )
                        .animate()
                        .fadeIn(duration: const Duration(milliseconds: 600)),
                    const SizedBox(height: 32),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              _currentUser?.name?.isNotEmpty == true
                                  ? _currentUser!.name[0].toUpperCase()
                                  : 'A',
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                        .animate()
                        .scale(duration: const Duration(milliseconds: 600)),
                    const SizedBox(height: 32),
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
                                    controller: _usernameController,
                                    enabled: _isEditing,
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
                                    controller: _addressController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Address',
                                      prefixIcon: const Icon(Icons.location_on,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    maxLines: 3,
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your address'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _mobileNoController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Phone Number',
                                      prefixIcon: const Icon(
                                          Icons.phone_outlined,
                                          color: Colors.white70),
                                      hintText: '10 digits (e.g., 9876543210)',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your phone number';
                                      }
                                      if (value.length != 10 ||
                                          !RegExp(r'^[0-9]{10}$')
                                              .hasMatch(value)) {
                                        return 'Enter a valid 10-digit phone number';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _aadharNoController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Aadhar Number',
                                      prefixIcon: const Icon(Icons.credit_card,
                                          color: Colors.white70),
                                      hintText:
                                          '12 digits (e.g., 123456789012)',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    maxLength: 12,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your Aadhar number';
                                      }
                                      if (value.length != 12 ||
                                          !RegExp(r'^[0-9]{12}$')
                                              .hasMatch(value)) {
                                        return 'Enter a valid 12-digit Aadhar number';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _panCardNoController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'PAN Card Number',
                                      prefixIcon: const Icon(Icons.credit_card,
                                          color: Colors.white70),
                                      hintText: 'ABCDE1234F',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    maxLength: 10,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your PAN card number';
                                      }
                                      if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$')
                                          .hasMatch(value.toUpperCase())) {
                                        return 'Enter a valid PAN number (e.g., ABCDE1234F)';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _voterIdNoController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Voter ID Number',
                                      prefixIcon: const Icon(Icons.credit_card,
                                          color: Colors.white70),
                                      hintText: 'e.g., ABC1234567',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your Voter ID number';
                                      }
                                      if (!RegExp(r'^[A-Z]{3}[0-9]{7}$')
                                          .hasMatch(value.toUpperCase())) {
                                        return 'Enter a valid Voter ID number (e.g., ABC1234567)';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _ageController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Age',
                                      prefixIcon: const Icon(Icons.cake,
                                          color: Colors.white70),
                                      hintText: 'Between 18-120',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    maxLength: 3,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your age';
                                      }
                                      final age = int.tryParse(value);
                                      if (age == null) {
                                        return 'Please enter a valid number';
                                      }
                                      if (age < 18) {
                                        return 'Age must be at least 18';
                                      }
                                      if (age > 120) {
                                        return 'Please enter a valid age';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedGender,
                                    onChanged: _isEditing
                                        ? (value) => setState(
                                            () => _selectedGender = value)
                                        : null,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Gender',
                                      prefixIcon: const Icon(Icons.person,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Male', child: Text('Male')),
                                      DropdownMenuItem(
                                          value: 'Female',
                                          child: Text('Female')),
                                      DropdownMenuItem(
                                          value: 'Other', child: Text('Other')),
                                    ],
                                    validator: (value) => value == null
                                        ? 'Please select your gender'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _constituencyController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Constituency',
                                      prefixIcon: const Icon(Icons.location_on,
                                          color: Colors.white70),
                                      hintText: 'Enter your constituency name',
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your constituency';
                                      }
                                      if (value.trim().isEmpty) {
                                        return 'Constituency name cannot be empty';
                                      }
                                      return null;
                                    },
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 24),
                                  if (_isEditing)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: _cancelEdit,
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16),
                                            ),
                                            child: Text(
                                              'Cancel',
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white70),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _saveProfile,
                                            style: AppTheme.elevatedButtonStyle,
                                            child: _isLoading
                                                ? const CircularProgressIndicator(
                                                    color: Colors.white)
                                                : const Text('Save'),
                                          ),
                                        ),
                                      ],
                                    ).animate().fadeIn(
                                        duration:
                                            const Duration(milliseconds: 600))
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _startEdit,
                                        style: AppTheme.elevatedButtonStyle,
                                        child: const Text('Edit Profile'),
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
}
