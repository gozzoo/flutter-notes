import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../models/note.dart';
import '../services/note_importer.dart';
import '../services/storage_service.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/note_editor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  final List<NoteMetadata> _items = [];
  int _selectedIndex = 0;
  Note? _selectedNote;
  bool _isLoadingNote = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isUpdatingEditors = false;
  Timer? _debounceTimer;
  bool _isDirty = false;

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
    _debounceTimer?.cancel();
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
    await _flushSave();
    List<NoteMetadata> items;
    if (_searchController.text.trim().isNotEmpty) {
      items = await StorageService.searchNotes(_searchController.text.trim());
    } else {
      items = StorageService.getNotesMeta();
    }

    // Sort by creationDate descending (Newest first)
    items.sort((a, b) {
      final dateComp = b.creationDate.compareTo(a.creationDate);
      if (dateComp != 0) return dateComp;
      return b.lastModified.compareTo(a.lastModified);
    });

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
          _confirmAndDeleteNote();
        }
      }
    }
  }

  Future<void> _selectItem(int index) async {
    if (_selectedIndex == index) return;
    await _flushSave();
    setState(() {
      _selectedIndex = index;
    });
    _saveSelection();
    _loadSelectedNote();
  }

  Future<void> _addNote() async {
    await _flushSave();
    final newNote = Note.create(content: 'New note');
    StorageService.addNote(newNote).then((_) {
      _loadNotes();
    });
  }

  Future<void> _importNotes() async {
    await _flushSave();
    try {
      final count = await NoteImporter.pickAndImport();
      if (mounted) {
        if (count > 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Imported $count notes')));
          _loadNotes();
        } else {
          // Could enable this if we distinguish cancel vs 0 imports
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(content: Text('No notes imported')),
          // );
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
    _debounceTimer?.cancel();
    if (_items.isEmpty) return;
    final idToDelete = _items[_selectedIndex].id;
    StorageService.deleteNote(idToDelete).then((_) {
      _loadNotes();
    });
  }

  Future<void> _confirmAndDeleteNote() async {
    if (_items.isEmpty) return;
    String name = "this note";
    if (_selectedNote != null &&
        _selectedNote!.id == _items[_selectedIndex].id) {
      name = '"${_selectedNote!.content.split('\n').first}"';
    }

    final ok = await DialogsHelper.showDeleteNoteDialog(context, name);
    if (ok) _deleteNote();
  }

  Future<void> _deleteAllNotes() async {
    final ok = await DialogsHelper.showDeleteAllNotesDialog(context);
    if (ok) {
      _debounceTimer?.cancel();
      await StorageService.deleteAllNotes();
      _loadNotes();
    }
  }

  void _onEditorChanged() {
    if (_isUpdatingEditors) return;
    if (_selectedNote == null) return;

    final title = _titleController.text;
    final body = _bodyController.text;
    final combined = body.isNotEmpty ? '$title\n$body' : title;

    if (_selectedNote!.content == combined) return;

    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _saveNow);
  }

  Future<void> _flushSave() async {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
      await _saveNow();
    }
  }

  Future<void> _saveNow() async {
    if (_selectedNote == null) return;

    final title = _titleController.text;
    final body = _bodyController.text;
    final combined = body.isNotEmpty ? '$title\n$body' : title;

    if (_selectedNote!.content != combined) {
      if (mounted) {
        setState(() {
          _selectedNote!.content = combined;
          _selectedNote!.lastModified = DateTime.now();
        });
      } else {
        _selectedNote!.content = combined;
        _selectedNote!.lastModified = DateTime.now();
      }
      await StorageService.updateNote(_selectedNote!);

      if (mounted) {
        final currentTitle = _titleController.text;
        final currentBody = _bodyController.text;
        final currentCombined = currentBody.isNotEmpty
            ? '$currentTitle\n$currentBody'
            : currentTitle;

        if (_selectedNote!.content == currentCombined) {
          setState(() {
            _isDirty = false;
          });
        }
      }
    } else {
      if (mounted && _isDirty) {
        setState(() {
          _isDirty = false;
        });
      }
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
              icon: const Icon(Icons.add),
              tooltip: 'Add note',
              onPressed: _addNote,
            ),
            PopupMenuButton<String>(
              tooltip: 'More options',
              onSelected: (value) {
                if (value == 'import') {
                  _importNotes();
                } else if (value == 'delete_all') {
                  _deleteAllNotes();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Import notes'),
                ),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Text('Delete all notes'),
                ),
              ],
            ),
          ],
        ),
        body: Row(
          children: [
            AppSidebar(
              items: _items,
              selectedIndex: _selectedIndex,
              isUnsaved: _isDirty,
              onItemSelected: _selectItem,
              searchController: _searchController,
              onSearchTriggered: _loadNotes,
            ),
            Expanded(
              child: _isLoadingNote
                  ? const Center(child: CircularProgressIndicator())
                  : NoteEditor(
                      titleController: _titleController,
                      bodyController: _bodyController,
                      note: _selectedNote,
                      onDelete: _items.isNotEmpty
                          ? _confirmAndDeleteNote
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
