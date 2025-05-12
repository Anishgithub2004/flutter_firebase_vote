import 'package:flutter/cupertino.dart';
/**
 * Created by Mahmud Ahsan
 * https://github.com/mahmudahsan
 */
import "package:flutter_firebase_vote/models/vote.dart";
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import "package:provider/provider.dart";
import "package:flutter_firebase_vote/state/vote.dart";

export 'auth_service.dart';
export 'vote_service.dart';

List<Vote> getVoteList() {
  List<Vote> voteList = [];
  const uuid = Uuid();

  voteList.add(Vote(
    voteId: uuid.v4(),
    voteTitle: 'Best Programming Language?',
    options: [
      {'Python': 0},
      {'JavaScript': 0},
      {'Dart': 0},
      {'Java': 0},
    ],
  ));

  voteList.add(Vote(
    voteId: uuid.v4(),
    voteTitle: 'Favorite Mobile Platform?',
    options: [
      {'Android': 0},
      {'iOS': 0},
      {'Cross-Platform': 0},
    ],
  ));

  return voteList;
}

// firestore collection name
const String kVotes = 'votes';
const String kTitle = 'title';

void getVoteListFromFirestore(BuildContext context) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  firestore.collection(kVotes).get().then((QuerySnapshot snapshot) {
    List<Vote> voteList = [];

    for (var doc in snapshot.docs) {
      voteList.add(mapFirestoreDocToVote(doc));
    }

    if (context.mounted) {
      Provider.of<VoteState>(context, listen: false).voteList = voteList;
    }
  });
}

Vote mapFirestoreDocToVote(DocumentSnapshot document) {
  Map<String, dynamic> data = document.data() as Map<String, dynamic>;
  String title = '';
  List<Map<String, int>> options = [];

  data.forEach((key, value) {
    if (key == kTitle) {
      title = value as String;
    } else {
      options.add({key: value as int});
    }
  });

  return Vote(
    voteId: document.id,
    voteTitle: title,
    options: options,
  );
}

void markVote(String voteId, String option) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  firestore.collection(kVotes).doc(voteId).update({
    option: FieldValue.increment(1),
  });
}

void retrieveMarkedVoteFromFirestore(
    {required String voteId, required BuildContext context}) {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Retrieve updated doc from server
  firestore.collection(kVotes).doc(voteId).get().then((document) {
    if (context.mounted && document.exists) {
      Provider.of<VoteState>(context, listen: false).activeVote =
          mapFirestoreDocToVote(document);
    }
  });
}
