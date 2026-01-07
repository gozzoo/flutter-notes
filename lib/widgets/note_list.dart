import 'package:flutter/material.dart';
import '../models/note.dart';
import 'note_list_item.dart';

class NoteList extends StatelessWidget {
  final List<NoteMetadata> items;
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
          final metadata = items[index];
          return NoteListItem(
            metadata: metadata,
            isSelected: index == selectedIndex,
            onTap: () => onItemSelected(index),
          );
        },
      ),
    );
  }
}
