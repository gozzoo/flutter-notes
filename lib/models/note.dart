import 'package:uuid/uuid.dart';

class Note {
  String id;
  String content;
  DateTime creationDate;
  DateTime lastModified;
  bool markdown;

  Note({
    required this.id,
    required this.content,
    required this.creationDate,
    required this.lastModified,
    this.markdown = true,
  });

  factory Note.create({required String content}) {
    final now = DateTime.now();
    return Note(
      id: const Uuid().v4(),
      content: content,
      creationDate: now,
      lastModified: now,
    );
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      content: json['content'] as String,
      creationDate: DateTime.parse(json['creationDate'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      markdown: json['markdown'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'creationDate': creationDate.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'markdown': markdown,
    };
  }
}
