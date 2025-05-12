import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/election_provider.dart';
import '../../services/mongodb_service.dart';

class ElectionManagementScreen extends StatefulWidget {
  const ElectionManagementScreen({super.key});

  @override
  State<ElectionManagementScreen> createState() =>
      _ElectionManagementScreenState();
}

class _ElectionManagementScreenState extends State<ElectionManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _candidateNameController = TextEditingController();
  final _candidatePartyController = TextEditingController();
  final _candidateManifestoController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _candidates = [];
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _candidateNameController.dispose();
    _candidatePartyController.dispose();
    _candidateManifestoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _addCandidate() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isUploading = true);

      try {
        String? photoUrl;
        if (_selectedImage != null) {
          // Upload to MongoDB
          photoUrl = await MongoDBService.uploadDocument(
            _selectedImage!,
            'candidate_photo',
            'election_candidate',
          );

          if (photoUrl == null) {
            throw Exception('Failed to upload candidate photo');
          }
        }

        setState(() {
          _candidates.add({
            'name': _candidateNameController.text,
            'party': _candidatePartyController.text,
            'manifesto': _candidateManifestoController.text,
            'photoUrl': photoUrl,
          });
          _candidateNameController.clear();
          _candidatePartyController.clear();
          _candidateManifestoController.clear();
          _selectedImage = null;
        });
      } catch (e) {
        print('Error adding candidate: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  void _removeCandidate(int index) {
    setState(() {
      _candidates.removeAt(index);
    });
  }

  Future<void> _createElection() async {
    if (_formKey.currentState!.validate() &&
        _startDate != null &&
        _endDate != null &&
        _candidates.isNotEmpty) {
      try {
        // Create election
        final electionRef =
            await FirebaseFirestore.instance.collection('elections').add({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'startDate': _startDate,
          'endDate': _endDate,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'totalVotes': 0,
          'status': 'active',
        });

        // Create candidates
        for (var candidate in _candidates) {
          await FirebaseFirestore.instance.collection('candidates').add({
            'name': candidate['name'],
            'party': candidate['party'],
            'manifesto': candidate['manifesto'],
            'electionId': electionRef.id,
            'voteCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'photoUrl': candidate['photoUrl'],
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Election created successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating election: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Election Management'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create New Election',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Election Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Start Date'),
                        subtitle: Text(_startDate?.toString() ?? 'Not set'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                          }
                        },
                      ),
                      ListTile(
                        title: const Text('End Date'),
                        subtitle: Text(_endDate?.toString() ?? 'Not set'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Add Candidates',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _candidateNameController,
                        decoration: const InputDecoration(
                          labelText: 'Candidate Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _candidatePartyController,
                        decoration: const InputDecoration(
                          labelText: 'Party',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _candidateManifestoController,
                        decoration: const InputDecoration(
                          labelText: 'Manifesto',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickImage,
                        icon: const Icon(Icons.image),
                        label: Text(_isUploading
                            ? 'Uploading...'
                            : 'Add Candidate Photo'),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedImage != null)
                        Image.file(
                          _selectedImage!,
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isUploading ? null : _addCandidate,
                        child: Text(
                            _isUploading ? 'Uploading...' : 'Add Candidate'),
                      ),
                      const SizedBox(height: 16),
                      if (_candidates.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Added Candidates:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _candidates.length,
                              itemBuilder: (context, index) {
                                final candidate = _candidates[index];
                                return Card(
                                  child: ListTile(
                                    leading: candidate['photoUrl'] != null
                                        ? Image.network(
                                            candidate['photoUrl'],
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(Icons.person);
                                            },
                                          )
                                        : const Icon(Icons.person),
                                    title: Text(candidate['name']),
                                    subtitle: Text(candidate['party']),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _removeCandidate(index),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isUploading ? null : _createElection,
                        child: Text(
                            _isUploading ? 'Uploading...' : 'Create Election'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Active Elections',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('elections')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final elections = snapshot.data?.docs ?? [];

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: elections.length,
                  itemBuilder: (context, index) {
                    final election =
                        elections[index].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(election['title'] ?? ''),
                        subtitle: Text(election['description'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await elections[index].reference.update({
                              'isActive': false,
                            });
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
