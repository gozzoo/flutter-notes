import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'services/storage_service.dart';
import 'widgets/note_list.dart';
import 'widgets/note_editor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await windowManager.ensureInitialized();
  await StorageService.restoreWindowBounds();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter-notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter notes'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  final List<String> _items = [];
  int _selectedIndex = 0;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isUpdatingEditors = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadNotes();
    _titleController.addListener(_onEditorChanged);
    _bodyController.addListener(_onEditorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _focusNode.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  void onWindowMoved() {
    _saveWindowBounds();
  }

  @override
  void onWindowResized() {
    _saveWindowBounds();
  }

  Future<void> _saveWindowBounds() async {
    final bounds = await windowManager.getBounds();
    await StorageService.saveWindowBounds(bounds);
  }

  void _loadNotes() {
    final items = StorageService.getNotes();
    final sel = StorageService.getSelectedIndex();

    setState(() {
      _items.clear();
      _items.addAll(items);
      if (_items.isNotEmpty) {
        _selectedIndex = sel.clamp(0, _items.length - 1);
      } else {
        _selectedIndex = 0;
      }
    });
    _updateEditorsFromSelected();
  }

  void _saveNotes() {
    StorageService.saveNotes(_items);
    StorageService.saveSelectedIndex(_selectedIndex);
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      if (isCtrl && key == LogicalKeyboardKey.keyN) {
        _addNote();
      } else if (key == LogicalKeyboardKey.delete) {
        _confirmDeleteDialog().then((ok) {
          if (ok) _deleteNote();
        });
      }
    }
  }

  void _selectItem(int index) {
    setState(() {
      _selectedIndex = index;
      _updateEditorsFromSelected();
    });
    _saveNotes();
  }

  void _addNote() {
    setState(() {
      _items.add('New note');
      _selectedIndex = _items.length - 1;
      _updateEditorsFromSelected();
    });
    _saveNotes();
  }

  void _deleteNote() {
    if (_items.isEmpty) return;
    setState(() {
      _items.removeAt(_selectedIndex);
      if (_items.isEmpty) {
        _selectedIndex = 0;
        _titleController.text = '';
        _bodyController.text = '';
      } else {
        _selectedIndex = _selectedIndex.clamp(0, _items.length - 1);
        _updateEditorsFromSelected();
      }
    });
    _saveNotes();
  }

  Future<bool> _confirmDeleteDialog() async {
    if (_items.isEmpty) return false;
    final name = _items[_selectedIndex].split('\n').first;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete note'),
          content: Text('Delete "$name"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  void _onEditorChanged() {
    if (_isUpdatingEditors) return;
    if (_items.isEmpty) return;
    final title = _titleController.text;
    final body = _bodyController.text;
    final combined = body.isNotEmpty ? '$title\n$body' : title;
    setState(() {
      _items[_selectedIndex] = combined;
    });
    _saveNotes();
  }

  void _updateEditorsFromSelected() {
    if (_items.isEmpty) {
      _isUpdatingEditors = true;
      _titleController.text = '';
      _bodyController.text = '';
      _isUpdatingEditors = false;
      return;
    }
    final full = _items[_selectedIndex];
    final parts = full.split('\n');
    final title = parts.isNotEmpty ? parts.first : '';
    final body = parts.length > 1 ? parts.sublist(1).join('\n') : '';
    _isUpdatingEditors = true;
    _titleController.text = title;
    _bodyController.text = body;
    _isUpdatingEditors = false;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add note',
              onPressed: _addNote,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete note',
              onPressed: _items.isNotEmpty
                  ? () async {
                      final ok = await _confirmDeleteDialog();
                      if (ok) _deleteNote();
                    }
                  : null,
            ),
          ],
        ),
        body: Row(
          children: [
            SizedBox(
              width: 300,
              child: NoteList(
                items: _items,
                selectedIndex: _selectedIndex,
                onItemSelected: _selectItem,
              ),
            ),
            Expanded(
              child: NoteEditor(
                titleController: _titleController,
                bodyController: _bodyController,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
