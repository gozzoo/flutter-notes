import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('notes');
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

class _MyHomePageState extends State<MyHomePage> {
  final List<String> _items = [];
  int _selectedIndex = 0;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isUpdatingEditors = false;

  void _loadNotes() {
    final box = Hive.box('notes');
    final items = box.get('items', defaultValue: []);
    final sel = box.get('selectedIndex', defaultValue: 0) as int;

    if (items is List) {
      setState(() {
        _items.clear();
        _items.addAll(items.cast<String>());
        if (_items.isNotEmpty) {
          _selectedIndex = sel.clamp(0, _items.length - 1);
        } else {
          _selectedIndex = 0;
        }
      });
      _updateEditorsFromSelected();
    }
  }

  void _saveNotes() {
    final box = Hive.box('notes');
    box.put('items', _items);
    box.put('selectedIndex', _selectedIndex);
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _titleController.addListener(_onEditorChanged);
    _bodyController.addListener(_onEditorChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
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

  // removed unused helper: editor updates items via _onEditorChanged

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
    // removed directly; prefer using confirmation via _confirmDelete
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
    final name = _items[_selectedIndex];
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

  // removed unused rename dialog helper

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
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final reverseIndex = _items.length - 1 - index;
                    final full = _items[reverseIndex];
                    final parts = full.split('\n');
                    final firstLine = parts.isNotEmpty ? parts.first : '';
                    // join all remaining lines into a single-line preview for subtitle
                    String secondLine = '';
                    if (parts.length > 1) {
                      secondLine = parts.sublist(1).join(' ').trim();
                    } else {
                      // for single-line items, show a short preview only if long
                      final trimmed = full.trim();
                      if (trimmed.length > 40) {
                        secondLine = trimmed.substring(0, 40).trim();
                      }
                    }
                    return ListTile(
                      title: Text(
                        firstLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: secondLine.isNotEmpty
                          ? Text(
                              secondLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha((0.7 * 255).round()),
                                  ),
                            )
                          : null,
                      selected: reverseIndex == _selectedIndex,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha((0.12 * 255).round()),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      onTap: () => _selectItem(reverseIndex),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _bodyController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
