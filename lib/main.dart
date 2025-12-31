import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

void main() {
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
      home: const MyHomePage(title: 'flutter-notes'),
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
  
  Future<File> get _localFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}hello_windows_notes.json');
  }

  Future<void> _loadNotes() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>?)?.map((e) => e as String).toList();
        final sel = data['selectedIndex'] as int?;
        if (items != null) {
          setState(() {
            _items.clear();
            _items.addAll(items);
            if (_items.isNotEmpty) {
              _selectedIndex = (sel ?? 0).clamp(0, _items.length - 1);
            } else {
              _selectedIndex = 0;
            }
          });
          // update editors after state set
          _updateEditorsFromSelected();
        }
      }
    } catch (e) {
      // ignore read errors
    }
  }

  Future<void> _saveNotes() async {
    try {
      final file = await _localFile;
      final data = {'items': _items, 'selectedIndex': _selectedIndex};
      await file.writeAsString(json.encode(data));
    } catch (e) {
      // ignore write errors
    }
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
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
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
                border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final full = _items[index];
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: secondLine.isNotEmpty
                        ? Text(
                            secondLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                                ),
                          )
                        : null,
                      selected: index == _selectedIndex,
                        selectedTileColor:
                          Theme.of(context).colorScheme.primary.withAlpha((0.12 * 255).round()),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      onTap: () => _selectItem(index),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(border: InputBorder.none),
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

 
