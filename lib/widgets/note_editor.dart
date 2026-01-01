import 'package:flutter/material.dart';

class NoteEditor extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController bodyController;

  const NoteEditor({
    super.key,
    required this.titleController,
    required this.bodyController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}
