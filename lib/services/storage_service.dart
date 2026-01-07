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

    // Migration logic
    if (_notesBox.containsKey('items')) {
      final items = _notesBox.get('items');
      final selIndex = _notesBox.get('selectedIndex', defaultValue: 0);
      _migrateWindowSettings();

      await _settingsBox.put('selectedIndex', selIndex);
      await _notesBox.clear();

      if (items is List) {
        // Migrate legacy list of strings
        for (var item in items) {
          if (item is String) {
            await _notesBox.add(Note.create(content: item).toJson());
          }
        }
      }
    } else {
      // Migrate existing individual string notes to Note objects
      // We iterate keys to modify safe
      final keys = _notesBox.keys.toList();
      for (var key in keys) {
        final val = _notesBox.get(key);
        if (val is String) {
          await _notesBox.put(key, Note.create(content: val).toJson());
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
  }

  static List<Note> getNotes() {
    return _notesBox.values.map((e) {
      if (e is Map) {
        // cast to Map<String, dynamic> safely
        return Note.fromJson(Map<String, dynamic>.from(e));
      } else if (e is String) {
        // Should have been migrated, but fallback
        return Note.create(content: e);
      }
      return Note.create(content: 'Error: invalid note format');
    }).toList();
  }

  static Future<void> addNote(Note note) async {
    await _notesBox.add(note.toJson());
  }

  static Future<void> updateNote(int index, Note note) async {
    await _notesBox.putAt(index, note.toJson());
  }

  static Future<void> deleteNote(int index) async {
    await _notesBox.deleteAt(index);
  }

  static int getSelectedIndex() {
    return _settingsBox.get('selectedIndex', defaultValue: 0) as int;
  }

  static Future<void> saveSelectedIndex(int index) async {
    await _settingsBox.put('selectedIndex', index);
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
