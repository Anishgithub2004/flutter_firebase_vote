import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/election.dart';

class ElectionResultsScreen extends StatefulWidget {
  final Election election;

  const ElectionResultsScreen({
    super.key,
    required this.election,
  });

  @override
  State<ElectionResultsScreen> createState() => _ElectionResultsScreenState();
}

class _ElectionResultsScreenState extends State<ElectionResultsScreen> {
  late Stream<DocumentSnapshot> _electionStream;
  late Stream<QuerySnapshot> _candidatesStream;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    try {
      if (widget.election.id.isEmpty) {
        throw Exception('Invalid election ID');
      }

      // Stream for election data
      _electionStream = FirebaseFirestore.instance
          .collection('elections')
          .doc(widget.election.id)
          .snapshots();

      // Stream for candidates data
      _candidatesStream = FirebaseFirestore.instance
          .collection('candidates')
          .where('electionId', isEqualTo: widget.election.id)
          .snapshots();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error setting up streams: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.election.title} - Results'),
        ),
        body: Center(
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _setupStreams();
                  });
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.election.title} - Results'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _electionStream,
        builder: (context, electionSnapshot) {
          if (electionSnapshot.hasError) {
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
                    'Error: ${electionSnapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          if (!electionSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final electionData =
              electionSnapshot.data!.data() as Map<String, dynamic>;
          final totalVotes = electionData['totalVotes'] as int? ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: _candidatesStream,
            builder: (context, candidatesSnapshot) {
              if (candidatesSnapshot.hasError) {
                return Center(
                  child: Text(
                      'Error loading candidates: ${candidatesSnapshot.error}'),
                );
              }

              if (!candidatesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final candidates = candidatesSnapshot.data!.docs;
              if (candidates.isEmpty) {
                return const Center(
                  child: Text('No candidates found for this election'),
                );
              }

              // Sort candidates by vote count in descending order
              candidates.sort((a, b) {
                final aVotes =
                    (a.data() as Map<String, dynamic>)['voteCount'] as int? ??
                        0;
                final bVotes =
                    (b.data() as Map<String, dynamic>)['voteCount'] as int? ??
                        0;
                return bVotes.compareTo(aVotes);
              });

              // Get the winning candidate
              final winningCandidate = candidates.first;
              final winningVotes = (winningCandidate.data()
                      as Map<String, dynamic>)['voteCount'] as int? ??
                  0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Election Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Total Votes: $totalVotes'),
                            if (winningVotes > 0)
                              Text(
                                'Leading Candidate: ${(winningCandidate.data() as Map<String, dynamic>)['name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Candidate Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...candidates.map((candidateDoc) {
                      final candidate =
                          candidateDoc.data() as Map<String, dynamic>;
                      final votes = candidate['voteCount'] as int? ?? 0;
                      final percentage = totalVotes > 0
                          ? (votes / totalVotes * 100).toStringAsFixed(1)
                          : '0.0';

                      return Card(
                        child: ListTile(
                          leading: candidate['photoUrl'] != null
                              ? Image.network(
                                  candidate['photoUrl'],
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.person),
                                )
                              : const Icon(Icons.person),
                          title:
                              Text(candidate['name'] as String? ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Party: ${candidate['party'] as String? ?? 'Unknown'}'),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: totalVotes > 0 ? votes / totalVotes : 0,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  candidateDoc.id == winningCandidate.id
                                      ? Colors.green
                                      : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          trailing: Text('$percentage% ($votes votes)'),
                        ),
                      );
                    }).toList(),
                    if (!electionData['isActive'] && totalVotes > 0)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          color: Colors.green[100],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                const Text(
                                  'Final Results',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Winner: ${(winningCandidate.data() as Map<String, dynamic>)['name']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Total Votes: $totalVotes',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
