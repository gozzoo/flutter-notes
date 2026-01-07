import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'models/note.dart';
import 'services/storage_service.dart';
import 'widgets/note_list.dart';
import 'widgets/note_editor.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  await WindowsSingleInstance.ensureSingleInstance(
    args,
    "flutter_notes",
    onSecondWindow: (args) async {
      // This code runs in the ALREADY OPEN instance
      await windowManager.show();
      await windowManager.focus();
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
    },
  );

  await StorageService.init();
  await windowManager.ensureInitialized();
  await StorageService.restoreWindowBounds();

  runApp(const FlutterNotesApp());
}

class FlutterNotesApp extends StatelessWidget {
  const FlutterNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter notes',
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
  final List<NoteMetadata> _items = [];
  int _selectedIndex = 0;
  Note? _selectedNote;
  bool _isLoadingNote = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
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
    _searchController.dispose();
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

  Future<void> _loadNotes() async {
    List<NoteMetadata> items;
    if (_searchController.text.trim().isNotEmpty) {
      items = await StorageService.searchNotes(_searchController.text.trim());
    } else {
      items = StorageService.getNotesMeta();
    }

    // Sort by creationDate descending (Newest first)
    items.sort((a, b) => b.creationDate.compareTo(a.creationDate));

    final selectedId = StorageService.getSelectedNoteId();

    if (mounted) {
      setState(() {
        _items.clear();
        _items.addAll(items);
        if (_items.isNotEmpty) {
          if (selectedId != null) {
            final index = _items.indexWhere((n) => n.id == selectedId);
            _selectedIndex = index != -1 ? index : 0;
          } else {
            _selectedIndex = 0;
          }
          _loadSelectedNote();
        } else {
          _selectedIndex = 0;
          _selectedNote = null;
          _updateEditorsFromSelected();
        }
      });
    }
  }

  Future<void> _loadSelectedNote() async {
    if (_items.isEmpty) return;

    setState(() {
      _isLoadingNote = true;
    });

    final id = _items[_selectedIndex].id;
    final note = await StorageService.getNote(id);

    if (mounted) {
      setState(() {
        _selectedNote = note;
        _isLoadingNote = false;
        _updateEditorsFromSelected();
      });
    }
  }

  Future<void> _saveSelection() async {
    if (_items.isNotEmpty &&
        _selectedIndex >= 0 &&
        _selectedIndex < _items.length) {
      await StorageService.saveSelectedNoteId(_items[_selectedIndex].id);
    } else {
      await StorageService.saveSelectedNoteId(null);
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      if (isCtrl && key == LogicalKeyboardKey.keyN) {
        _addNote();
      } else if (key == LogicalKeyboardKey.delete) {
        if (_items.isNotEmpty) {
          _confirmDeleteDialog().then((ok) {
            if (ok) _deleteNote();
          });
        }
      }
    }
  }

  void _selectItem(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    _saveSelection();
    _loadSelectedNote();
  }

  void _addNote() {
    final newNote = Note.create(content: 'New note');
    StorageService.addNote(newNote).then((_) {
      // Refresh list logic
      // Ideally we just insert the meta and select it, but reloading is safer for sort sync
      _loadNotes(); // This might be slightly inefficient if list is huge, but reloading meta is fast
    });
  }

  Future<void> _importNotes() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
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
                // Try to parse full Note object if format matches
                final note = Note.fromJson(item);
                await StorageService.addNote(note);
                importedCount++;
              } catch (_) {
                // Fallback if full parse fails but content exists
                if (item.containsKey('content')) {
                  final note = Note.create(content: item['content']);
                  await StorageService.addNote(note);
                  importedCount++;
                }
              }
            }
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported $importedCount notes')),
            );
          }
          _loadNotes();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid file format')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error importing notes: $e')));
      }
    }
  }

  void _deleteNote() {
    if (_items.isEmpty) return;
    final idToDelete = _items[_selectedIndex].id;
    StorageService.deleteNote(idToDelete).then((_) {
      _loadNotes(); // Simplest way to refresh list and selection
    });
  }

  Future<bool> _confirmDeleteDialog() async {
    if (_items.isEmpty) return false;
    // We try to show name if loaded, otherwise just "this note"
    String name = "this note";
    if (_selectedNote != null &&
        _selectedNote!.id == _items[_selectedIndex].id) {
      name = '"${_selectedNote!.content.split('\n').first}"';
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete note'),
          content: Text('Delete $name? This cannot be undone.'),
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
    if (_selectedNote == null) return;

    final title = _titleController.text;
    final body = _bodyController.text;
    final combined = body.isNotEmpty ? '$title\n$body' : title;

    // Check if content actually changed to avoid unnecessary disk writes if listener triggers frequently
    if (_selectedNote!.content != combined) {
      // Update in memory
      setState(() {
        _selectedNote!.content = combined;
        _selectedNote!.lastModified = DateTime.now();
      });
      // Save to disk (Async background)
      StorageService.updateNote(_selectedNote!);
      // Note: We are not refreshing the list headers immediately to avoid jumpiness,
      // but the lastModified date in the list might be stale until reload.
      // This is acceptable.
    }
  }

  void _updateEditorsFromSelected() {
    if (_selectedNote == null) {
      _isUpdatingEditors = true;
      _titleController.text = '';
      _bodyController.text = '';
      _isUpdatingEditors = false;
      return;
    }

    final full = _selectedNote!.content;
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
              icon: const Icon(Icons.file_upload),
              tooltip: 'Import notes',
              onPressed: _importNotes,
            ),
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
                  border: Border(right: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, value, _) {
                          return TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: value.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        _loadNotes();
                                      },
                                    )
                                  : null,
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            // Trigger search on submit (Enter key)
                            onSubmitted: (_) => _loadNotes(),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: NoteList(
                        items: _items,
                        selectedIndex: _selectedIndex,
                        onItemSelected: _selectItem,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoadingNote
                  ? const Center(child: CircularProgressIndicator())
                  : NoteEditor(
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
