import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/storage_service.dart';

class NoteListItem extends StatefulWidget {
  final NoteMetadata metadata;
  final bool isSelected;
  final VoidCallback onTap;

  const NoteListItem({
    super.key,
    required this.metadata,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<NoteListItem> {
  Note? _note;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void didUpdateWidget(covariant NoteListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metadata.id != widget.metadata.id) {
      _loadNote();
    }
  }

  Future<void> _loadNote() async {
    // If the widget is removed from tree before load completes, we handle mounted check
    setState(() {
      _isLoading = true;
    });

    final note = await StorageService.getNote(widget.metadata.id);

    if (mounted) {
      setState(() {
        _note = note;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListTile(
        title: Container(
          height: 16,
          width: double.infinity,
          color: Colors.grey[300],
        ),
        subtitle: Container(height: 12, width: 100, color: Colors.grey[200]),
        selected: widget.isSelected,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primary.withAlpha((0.12 * 255).round()),
      );
    }

    if (_note == null) {
      return const SizedBox.shrink(); // Should not happen if data integrity is good
    }

    final full = _note!.content;
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
        firstLine.isEmpty ? 'Untitled' : firstLine,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: secondLine.isNotEmpty
          ? Text(
              secondLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
              ),
            )
          : null,
      selected: widget.isSelected,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primary.withAlpha((0.12 * 255).round()),
      selectedColor: Theme.of(context).colorScheme.primary,
      onTap: widget.onTap,
    );
  }
}
