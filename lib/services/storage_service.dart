import 'dart:ui';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../models/note.dart';

class StorageService {
  static const String _notesBoxName = 'notes';
  static const String _settingsBoxName = 'settings';
  static const String _metaBoxName = 'notes_meta';

  static late LazyBox _notesBox;
  static late Box _settingsBox;
  static late Box _metaBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _notesBox = await Hive.openLazyBox(_notesBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _metaBox = await Hive.openBox(_metaBoxName);

    // Ensure window settings are moved to settings box before we potentially clear notes box
    await _migrateWindowSettings();

    // Migrations
    await _performMigrations();

    // Ensure Meta Index exists
    await _ensureMetaIndex();
  }

  static Future<void> _performMigrations() async {
    // 1. Handle Legacy "Large List" migration if "items" exists
    if (_notesBox.containsKey('items')) {
      final items = await _notesBox.get('items');
      await _notesBox.clear();
      await _metaBox.clear();

      if (items is List) {
        for (var item in items) {
          if (item is String) {
            final note = Note.create(content: item);
            await addNote(note);
          }
        }
      }
    }
    // 2. Handle Integer Key migration
    else if (_notesBox.isNotEmpty) {
      bool neededMigration = false;
      // Check if any key is int
      for (var key in _notesBox.keys) {
        if (key is int) {
          neededMigration = true;
          break;
        }
      }

      if (neededMigration) {
        final Map<String, Map<String, dynamic>> newEntries = {};

        // We have to iterate keys.
        // Copy to list to avoid concurrency issues during iteration
        final keys = _notesBox.keys.toList();

        for (var key in keys) {
          if (key is String) continue;

          final val = await _notesBox.get(key);
          Note note;
          if (val is Map) {
            note = Note.fromJson(Map<String, dynamic>.from(val));
          } else if (val is String) {
            note = Note.create(content: val);
          } else {
            continue;
          }
          newEntries[note.id] = note.toJson();
        }

        await _notesBox.clear();
        await _metaBox.clear();
        for (var entry in newEntries.entries) {
          // We can't use putAll on LazyBox easily with async, loop is fine
          final note = Note.fromJson(entry.value);
          await addNote(note);
        }
      }
    }
  }

  static Future<void> _ensureMetaIndex() async {
    // robust sync: check for keys in notesBox that are missing in metaBox
    final notesKeys = _notesBox.keys.toSet();
    final metaKeys = _metaBox.keys.toSet();

    final missing = notesKeys.difference(metaKeys);
    if (missing.isNotEmpty) {
      for (var key in missing) {
        final val = await _notesBox.get(key);
        if (val is Map) {
          final note = Note.fromJson(Map<String, dynamic>.from(val));
          await _updateMeta(note);
        }
      }
    }

    // cleanup orphans (meta exists but note deleted externally?)
    final orphans = metaKeys.difference(notesKeys);
    for (var key in orphans) {
      await _metaBox.delete(key);
    }
  }

  static Future<void> _updateMeta(Note note) async {
    await _metaBox.put(note.id, {
      'id': note.id,
      'creationDate': note.creationDate.toIso8601String(),
      'lastModified': note.lastModified.toIso8601String(),
    });
  }

  static Future<void> _migrateWindowSettings() async {
    // Since _notesBox is LazyBox, get is async
    final x = await _notesBox.get('window_x');
    final y = await _notesBox.get('window_y');
    final width = await _notesBox.get('window_width');
    final height = await _notesBox.get('window_height');

    if (x != null) await _settingsBox.put('window_x', x);
    if (y != null) await _settingsBox.put('window_y', y);
    if (width != null) await _settingsBox.put('window_width', width);
    if (height != null) await _settingsBox.put('window_height', height);

    if (x != null) await _notesBox.delete('window_x');
    if (y != null) await _notesBox.delete('window_y');
    if (width != null) await _notesBox.delete('window_width');
    if (height != null) await _notesBox.delete('window_height');
  }

  // OLD: static List<Note> getNotes()
  // NEW: Get Metadata List
  static List<NoteMetadata> getNotesMeta() {
    return _metaBox.values.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return NoteMetadata(
        id: map['id'],
        creationDate: DateTime.parse(map['creationDate']),
        lastModified: DateTime.parse(map['lastModified']),
      );
    }).toList();
  }

  static Future<Note?> getNote(String id) async {
    final val = await _notesBox.get(id);
    if (val != null && val is Map) {
      return Note.fromJson(Map<String, dynamic>.from(val));
    }
    return null;
  }

  static Future<void> addNote(Note note) async {
    await _notesBox.put(note.id, note.toJson());
    await _updateMeta(note);
  }

  static Future<void> updateNote(Note note) async {
    await _notesBox.put(note.id, note.toJson());
    await _updateMeta(note);
  }

  static Future<void> deleteNote(String id) async {
    await _notesBox.delete(id);
    await _metaBox.delete(id);
  }

  static String? getSelectedNoteId() {
    return _settingsBox.get('selected_note_id') as String?;
  }

  static Future<void> saveSelectedNoteId(String? id) async {
    if (id == null) {
      await _settingsBox.delete('selected_note_id');
    } else {
      await _settingsBox.put('selected_note_id', id);
    }
  }

  static Future<void> saveWindowBounds(Rect bounds) async {
    await _settingsBox.put('window_x', bounds.left);
    await _settingsBox.put('window_y', bounds.top);
    await _settingsBox.put('window_width', bounds.width);
    await _settingsBox.put('window_height', bounds.height);
  }

  static Future<void> restoreWindowBounds() async {
    final double? x = _settingsBox.get('window_x');
    final double? y = _settingsBox.get('window_y');
    final double? width = _settingsBox.get('window_width');
    final double? height = _settingsBox.get('window_height');

    if (x != null && y != null && width != null && height != null) {
      await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
    }
  }

  static Future<List<NoteMetadata>> searchNotes(String query) async {
    final queryLower = query.toLowerCase();
    final matchedIds = <String>{};

    // Iterate all notes to check content
    for (var key in _notesBox.keys) {
      final val = await _notesBox.get(key);
      if (val is Map) {
        final content = val['content'] as String? ?? '';
        if (content.toLowerCase().contains(queryLower)) {
          matchedIds.add(key as String);
        }
      }
    }

    return _metaBox.values
        .where((e) {
          final map = e as Map;
          return matchedIds.contains(map['id']);
        })
        .map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return NoteMetadata(
            id: map['id'],
            creationDate: DateTime.parse(map['creationDate']),
            lastModified: DateTime.parse(map['lastModified']),
          );
        })
        .toList();
  }
}
