import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/mongodb_service.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

class VoterProfileScreen extends StatefulWidget {
  const VoterProfileScreen({Key? key}) : super(key: key);

  @override
  _VoterProfileScreenState createState() => _VoterProfileScreenState();
}

class _VoterProfileScreenState extends State<VoterProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _constituencyNameController = TextEditingController();
  final _constituencyNumberController = TextEditingController();
  final _aadharNumberController = TextEditingController();
  final _panNumberController = TextEditingController();
  final _voterIdNumberController = TextEditingController();
  String? _selectedGender;

  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  bool _isLoading = false;
  bool _isEditing = false;
  UserModel? _currentUser;
  File? _aadharCardFile;
  File? _panCardFile;
  File? _voterIdFile;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _constituencyNameController.dispose();
    _constituencyNumberController.dispose();
    _aadharNumberController.dispose();
    _panNumberController.dispose();
    _voterIdNumberController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _nameController.text = user.name;
        _phoneController.text = user.phone;
        _ageController.text = user.age?.toString() ?? '';
        _addressController.text = user.address ?? '';
        _constituencyNameController.text = user.constituencyName ?? '';
        _constituencyNumberController.text = user.constituencyNumber ?? '';
        _aadharNumberController.text = user.aadharNumber ?? '';
        _panNumberController.text = user.panNumber ?? '';
        _voterIdNumberController.text = user.voterIdNumber ?? '';
        _selectedGender = user.gender;
      });
    } catch (e) {
      _showError('Error loading profile: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDocument(String type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // Ensure we get the file data
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        print('Picked file name: ${pickedFile.name}');
        print('Picked file size: ${pickedFile.size} bytes');

        if (kIsWeb) {
          if (pickedFile.bytes != null) {
            print('Selected file (web): ${pickedFile.name}');
            // Handle web file upload
          } else {
            print('No bytes found for the selected file.');
          }
        } else {
          if (pickedFile.path != null) {
            final file = File(pickedFile.path!);
            // Verify file exists
            if (await file.exists()) {
              print('Selected file (mobile): ${file.path}');
              print('File exists: true');
              print('File size: ${await file.length()} bytes');

              setState(() {
                switch (type) {
                  case 'aadhar':
                    _aadharCardFile = file;
                    break;
                  case 'pan':
                    _panCardFile = file;
                    break;
                  case 'voter':
                    _voterIdFile = file;
                    break;
                }
              });
            } else {
              print('File does not exist at path: ${file.path}');
              _showError('Selected file does not exist');
            }
          } else {
            print('No file path available.');
            _showError('Could not get file path');
          }
        }
      } else {
        print('No file selected.');
      }
    } catch (e) {
      print('Error picking document: ${e.toString()}');
      _showError('Error picking document: ${e.toString()}');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    print('Starting profile save...');

    try {
      String? aadharUrl, panUrl, voterIdUrl;

      // Upload KYC documents to MongoDB
      if (_aadharCardFile != null) {
        print('Uploading Aadhaar card to MongoDB...');
        aadharUrl = await MongoDBService.uploadKYCDocument(
          userId: _currentUser!.uid,
          documentType: 'aadhar',
          filePath: _aadharCardFile!.path,
        );
        if (aadharUrl != null) {
          print('Aadhaar card uploaded to MongoDB: $aadharUrl');
        }
      }

      if (_panCardFile != null) {
        print('Uploading PAN card to MongoDB...');
        panUrl = await MongoDBService.uploadKYCDocument(
          userId: _currentUser!.uid,
          documentType: 'pan',
          filePath: _panCardFile!.path,
        );
        if (panUrl != null) {
          print('PAN card uploaded to MongoDB: $panUrl');
        }
      }

      if (_voterIdFile != null) {
        print('Uploading Voter ID to MongoDB...');
        voterIdUrl = await MongoDBService.uploadKYCDocument(
          userId: _currentUser!.uid,
          documentType: 'voter',
          filePath: _voterIdFile!.path,
        );
        if (voterIdUrl != null) {
          print('Voter ID uploaded to MongoDB: $voterIdUrl');
        }
      }

      // Update user profile with the MongoDB URLs
      final updatedUser = _currentUser!.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        age: int.tryParse(_ageController.text),
        address: _addressController.text.trim(),
        constituencyName: _constituencyNameController.text.trim(),
        constituencyNumber: _constituencyNumberController.text.trim(),
        aadharNumber: _aadharNumberController.text.trim(),
        panNumber: _panNumberController.text.trim(),
        voterIdNumber: _voterIdNumberController.text.trim(),
        gender: _selectedGender,
        aadharCardUrl: aadharUrl ?? _currentUser!.aadharCardUrl,
        panCardUrl: panUrl ?? _currentUser!.panCardUrl,
        voterIdUrl: voterIdUrl ?? _currentUser!.voterIdUrl,
      );

      await _userService.updateProfile(updatedUser);
      setState(() {
        _currentUser = updatedUser;
        _isEditing = false;
      });
      _showSuccess('Profile updated successfully');
      print('Profile updated successfully.');
    } catch (e) {
      print('Error updating profile: ${e.toString()}');
      _showError('Error updating profile: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
      print('Profile save process completed.');
    }
  }

  Future<void> _viewDocument(String documentUrl) async {
    try {
      setState(() => _isLoading = true);
      print('Fetching document from URL: $documentUrl');

      final documentId = documentUrl.split('/').last;
      final file = await MongoDBService.getKYCDocument(documentId);

      if (file != null) {
        if (mounted) {
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
      } else {
        _showError('Could not load document');
      }
    } catch (e) {
      print('Error viewing document: $e');
      _showError('Error viewing document: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDocument(String type) async {
    try {
      setState(() => _isLoading = true);

      // Get the document ID from MongoDB
      final documents =
          await MongoDBService.getUserDocuments(_currentUser!.uid);
      final document = documents.firstWhere(
        (doc) =>
            doc['documentType'] ==
            switch (type) {
              'aadhar' => 'aadhar_card',
              'pan' => 'pan_card',
              'voter' => 'voter_id',
              _ => type,
            },
        orElse: () => {},
      );

      if (document.isEmpty) {
        _showError('Document not found');
        return;
      }

      // Delete the document
      final success = await MongoDBService.deleteDocument(document['_id']);
      if (success) {
        setState(() {
          switch (type) {
            case 'aadhar':
              _aadharCardFile = null;
              break;
            case 'pan':
              _panCardFile = null;
              break;
            case 'voter':
              _voterIdFile = null;
              break;
          }
        });
        _showSuccess('Document deleted successfully');
      } else {
        _showError('Failed to delete document');
      }
    } catch (e) {
      print('Error deleting document: $e');
      _showError('Error deleting document: ${e.toString()}');
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
        content: Text(message),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
              if (url != null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteDocument(type),
                  tooltip: 'Delete Document',
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
                          'Profile',
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
                                  : 'V',
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextFormField(
                                    controller: _nameController,
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
                                    controller: _phoneController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Phone Number',
                                      prefixIcon: const Icon(
                                          Icons.phone_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your phone number'
                                        : null,
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
                                      prefixIcon: const Icon(
                                          Icons.cake_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your age'
                                        : null,
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
                                      prefixIcon: const Icon(
                                          Icons.person_outline,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    dropdownColor: AppTheme.primaryColor,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Male',
                                          child: Text('Male',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      DropdownMenuItem(
                                          value: 'Female',
                                          child: Text('Female',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                      DropdownMenuItem(
                                          value: 'Other',
                                          child: Text('Other',
                                              style: TextStyle(
                                                  color: Colors.white))),
                                    ],
                                    validator: (value) => value == null
                                        ? 'Please select your gender'
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
                                      prefixIcon: const Icon(
                                          Icons.home_outlined,
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
                                    controller: _constituencyNameController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Constituency Name',
                                      prefixIcon: const Icon(
                                          Icons.location_city_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your constituency name'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _constituencyNumberController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Constituency Number',
                                      prefixIcon: const Icon(
                                          Icons.format_list_numbered_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your constituency number'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _aadharNumberController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Aadhaar Number',
                                      prefixIcon: const Icon(
                                          Icons.credit_card_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your Aadhaar number'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _panNumberController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'PAN Number',
                                      prefixIcon: const Icon(
                                          Icons.credit_card_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your PAN number'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _voterIdNumberController,
                                    enabled: _isEditing,
                                    decoration:
                                        AppTheme.inputDecoration.copyWith(
                                      labelText: 'Voter ID Number',
                                      prefixIcon: const Icon(
                                          Icons.credit_card_outlined,
                                          color: Colors.white70),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Please enter your Voter ID number'
                                        : null,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Documents',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 16),
                                  _buildDocumentUpload(
                                    'Aadhaar Card',
                                    'aadhar',
                                    _aadharCardFile,
                                    _currentUser?.aadharCardUrl,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  _buildDocumentUpload(
                                    'PAN Card',
                                    'pan',
                                    _panCardFile,
                                    _currentUser?.panCardUrl,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  _buildDocumentUpload(
                                    'Voter ID',
                                    'voter',
                                    _voterIdFile,
                                    _currentUser?.voterIdUrl,
                                  ).animate().fadeIn(
                                      duration:
                                          const Duration(milliseconds: 600)),
                                  const SizedBox(height: 24),
                                  if (_isEditing)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () => setState(
                                                () => _isEditing = false),
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
                                        onPressed: () =>
                                            setState(() => _isEditing = true),
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
