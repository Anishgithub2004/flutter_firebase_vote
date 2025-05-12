class Vote {
  final String voteId;
  final String voteTitle;
  final List<Map<String, int>> options;

  Vote({
    required this.voteId,
    required this.voteTitle,
    required this.options,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': voteTitle,
      ...options.fold<Map<String, dynamic>>({}, (map, option) {
        map[option.keys.first] = option.values.first;
        return map;
      }),
    };
  }

  // Create a Vote from Firestore document
  factory Vote.fromFirestore(String voteId, Map<String, dynamic> data) {
    final title = data['title'] as String;
    final options = data.entries
        .where((entry) => entry.key != 'title')
        .map((entry) => {entry.key: entry.value as int})
        .toList();

    return Vote(
      voteId: voteId,
      voteTitle: title,
      options: options,
    );
  }

  // Convert Vote to Firestore document
  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      'title': voteTitle,
    };

    for (var option in options) {
      option.forEach((key, value) {
        data[key] = value;
      });
    }

    return data;
  }
}
