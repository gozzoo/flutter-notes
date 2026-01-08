import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import '../models/note.dart';
import '../services/storage_service.dart';

class NoteImporter {
  /// Picks a JSON file and imports notes from it.
  /// Returns the number of notes successfully imported.
  /// Throws specific exceptions or returns -1 on user cancellation/error if needed,
  /// but typically we treat null/empty as cancellation or no-op.
  static Future<int> pickAndImport() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return 0; // Cancelled
    }

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final json = jsonDecode(content);

    if (json is Map &&
        json.containsKey('activeNotes') &&
        json['activeNotes'] is List) {
      final notes = json['activeNotes'] as List;
      int importedCount = 0;
      for (var item in notes) {
        if (item is Map<String, dynamic>) {
          try {
            await _importSingleNote(item);
            importedCount++;
          } catch (_) {
            // Error importing single note, skip
          }
        }
      }
      return importedCount;
    } else {
      throw const FormatException(
        'Invalid file format: JSON must contain "activeNotes" list.',
      );
    }
  }

  static Future<void> _importSingleNote(Map<String, dynamic> item) async {
    try {
      // Try to parse full Note object if format matches
      final note = Note.fromJson(item);
      await StorageService.addNote(note);
    } catch (_) {
      // Fallback if full parse fails but content exists
      if (item.containsKey('content')) {
        DateTime? creationDate;
        if (item.containsKey('creationDate')) {
          try {
            creationDate = DateTime.parse(item['creationDate']);
          } catch (_) {}
        }

        DateTime? lastModified;
        if (item.containsKey('lastModified')) {
          try {
            lastModified = DateTime.parse(item['lastModified']);
          } catch (_) {}
        }

        final note = Note.create(
          content: item['content'],
          creationDate: creationDate,
          lastModified: lastModified,
        );
        await StorageService.addNote(note);
      } else {
        throw Exception('Note content missing');
      }
    }
  }
}
