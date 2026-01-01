import 'dart:ui';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

class StorageService {
  static const String _notesBoxName = 'notes';
  static const String _settingsBoxName = 'settings';

  static late Box _notesBox;
  static late Box _settingsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _notesBox = await Hive.openBox(_notesBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);

    // Migration logic: Check if the 'notes' box contains the legacy 'items' list
    if (_notesBox.containsKey('items')) {
      final items = _notesBox.get('items');
      final selIndex = _notesBox.get('selectedIndex', defaultValue: 0);
      final x = _notesBox.get('window_x');
      final y = _notesBox.get('window_y');
      final width = _notesBox.get('window_width');
      final height = _notesBox.get('window_height');

      // Save settings to the new settings box
      await _settingsBox.put('selectedIndex', selIndex);
      if (x != null) await _settingsBox.put('window_x', x);
      if (y != null) await _settingsBox.put('window_y', y);
      if (width != null) await _settingsBox.put('window_width', width);
      if (height != null) await _settingsBox.put('window_height', height);

      // Clear the notes box to remove legacy keys including 'items'
      await _notesBox.clear();

      // Repopulate notes box as a collection (individual entries)
      if (items is List) {
        await _notesBox.addAll(items.cast<String>());
      }
    }
  }

  // Notes are now stored as individual values in the box.
  // We use values.toList() to retrieve them.
  // Hive preserves insertion order for integer keys (0, 1, 2...).
  static List<String> getNotes() {
    return _notesBox.values.cast<String>().toList();
  }

  static Future<void> addNote(String content) async {
    await _notesBox.add(content);
  }

  static Future<void> updateNote(int index, String content) async {
    await _notesBox.putAt(index, content);
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
