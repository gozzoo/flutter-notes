import 'package:flutter/material.dart';
import '../models/note.dart';

class NoteListItem extends StatelessWidget {
  final NoteMetadata metadata;
  final bool isSelected;
  final bool isUnsaved;
  final VoidCallback onTap;
  final bool isScrolling;

  const NoteListItem({
    super.key,
    required this.metadata,
    required this.isSelected,
    this.isUnsaved = false,
    required this.onTap,
    this.isScrolling = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListTile(
        hoverColor: isScrolling ? Colors.transparent : null,
        contentPadding: const EdgeInsets.only(left: 4, right: 12),
        title: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: isUnsaved
                  ? Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                metadata.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            metadata.preview.isNotEmpty ? metadata.preview : ' ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            ),
          ),
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primary.withAlpha((0.12 * 255).round()),
        selectedColor: Theme.of(context).colorScheme.primary,
        onTap: onTap,
      ),
    );
  }
}
