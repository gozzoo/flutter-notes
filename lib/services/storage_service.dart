import 'dart:ui';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';
import '../models/note.dart';

class StorageService {
  static const String _notesBoxName = 'notes';
  static const String _settingsBoxName = 'settings';

  static late Box _notesBox;
  static late Box _settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _notesBox = await Hive.openBox(_notesBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);

    // Ensure window settings are moved to settings box before we potentially clear notes box
    await _migrateWindowSettings();

    // 1. Handle Legacy "Large List" migration if "items" exists
    if (_notesBox.containsKey('items')) {
      final items = _notesBox.get('items');
      // Try to rescue selection index
      // final selIndex = _notesBox.get('selectedIndex', defaultValue: 0);
      // await _settingsBox.put('selectedIndex', selIndex); // We are moving to IDs, but saving index is okay for now or ignore.

      await _notesBox.clear();

      if (items is List) {
        for (var item in items) {
          if (item is String) {
            final note = Note.create(content: item);
            await _notesBox.put(note.id, note.toJson());
          }
        }
      }
    }
    // 2. Handle Integer Key migration (The box has items, but they are keyed by int)
    else if (_notesBox.isNotEmpty) {
      // If there is at least one integer key, we assume we need to migrate entire box to UUID keys
      if (_notesBox.keys.any((k) => k is int)) {
        final Map<String, Map<String, dynamic>> newEntries = {};

        for (var key in _notesBox.keys) {
          if (key is String)
            continue; // Skip string keys (like potential settings leftovers)

          final val = _notesBox.get(key);
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
        for (var entry in newEntries.entries) {
          await _notesBox.put(entry.key, entry.value);
        }
      }
    }
  }

  static Future<void> _migrateWindowSettings() async {
    final x = _notesBox.get('window_x');
    final y = _notesBox.get('window_y');
    final width = _notesBox.get('window_width');
    final height = _notesBox.get('window_height');
    if (x != null) await _settingsBox.put('window_x', x);
    if (y != null) await _settingsBox.put('window_y', y);
    if (width != null) await _settingsBox.put('window_width', width);
    if (height != null) await _settingsBox.put('window_height', height);

    // Cleanup old settings from notes box
    if (x != null) await _notesBox.delete('window_x');
    if (y != null) await _notesBox.delete('window_y');
    if (width != null) await _notesBox.delete('window_width');
    if (height != null) await _notesBox.delete('window_height');
  }

  static List<Note> getNotes() {
    return _notesBox.values.map((e) {
      if (e is Map) {
        return Note.fromJson(Map<String, dynamic>.from(e));
      } else if (e is String) {
        return Note.create(content: e);
      }
      return Note.create(content: 'Error: invalid note format');
    }).toList();
  }

  static Future<void> addNote(Note note) async {
    await _notesBox.put(note.id, note.toJson());
  }

  static Future<void> updateNote(Note note) async {
    await _notesBox.put(note.id, note.toJson());
  }

  static Future<void> deleteNote(String id) async {
    await _notesBox.delete(id);
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
}
