import 'package:flutter/material.dart';
import '../models/note.dart';

class NoteList extends StatelessWidget {
  final List<Note> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const NoteList({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey[300],
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final note = items[index];
          final full = note.content;
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
            selected: index == selectedIndex,
            selectedTileColor: Theme.of(
              context,
            ).colorScheme.primary.withAlpha((0.12 * 255).round()),
            selectedColor: Theme.of(context).colorScheme.primary,
            onTap: () => onItemSelected(index),
          );
        },
      ),
    );
  }
}
