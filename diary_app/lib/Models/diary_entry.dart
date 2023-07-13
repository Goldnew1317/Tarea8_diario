class DiaryEntry {
  int? id;
  String title;
  DateTime date;
  String description;
  String? photo;
  String? audio;

  DiaryEntry({
    this.id,
    required this.title,
    required this.date,
    required this.description,
    this.photo,
    this.audio,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'photo': photo,
      'audio': audio,
    };
  }

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'],
      title: map['title'],
      date: DateTime.parse(map['date']),
      description: map['description'],
      photo: map['photo'],
      audio: map['audio'],
    );
  }
}
