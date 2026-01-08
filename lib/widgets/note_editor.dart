import 'package:flutter/material.dart';
import '../models/note.dart';

class NoteEditor extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final Note? note;

  const NoteEditor({
    super.key,
    required this.titleController,
    required this.bodyController,
    this.note,
  });

  void _showMetadata(BuildContext context) {
    if (note == null) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Note Metadata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Created: ${_formatDate(note!.creationDate)}'),
              const SizedBox(height: 8),
              Text('Last Modified: ${_formatDate(note!.lastModified)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
            ],
          ),
        ),
        if (note != null)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => _showMetadata(context),
              color: Colors.grey,
              tooltip: 'Metadata',
            ),
          ),
      ],
    );
  }
}
