import 'dart:ui';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

class StorageService {
  static const String _boxName = 'notes';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

  static List<String> getNotes() {
    final items = _box.get('items', defaultValue: []);
    if (items is List) {
      return items.cast<String>();
    }
    return [];
  }

  static Future<void> saveNotes(List<String> notes) async {
    await _box.put('items', notes);
  }

  static int getSelectedIndex() {
    return _box.get('selectedIndex', defaultValue: 0) as int;
  }

  static Future<void> saveSelectedIndex(int index) async {
    await _box.put('selectedIndex', index);
  }

  static Future<void> saveWindowBounds(Rect bounds) async {
    await _box.put('window_x', bounds.left);
    await _box.put('window_y', bounds.top);
    await _box.put('window_width', bounds.width);
    await _box.put('window_height', bounds.height);
  }

  static Future<void> restoreWindowBounds() async {
    final double? x = _box.get('window_x');
    final double? y = _box.get('window_y');
    final double? width = _box.get('window_width');
    final double? height = _box.get('window_height');

    if (x != null && y != null && width != null && height != null) {
      await windowManager.setBounds(Rect.fromLTWH(x, y, width, height));
    }
  }
}
