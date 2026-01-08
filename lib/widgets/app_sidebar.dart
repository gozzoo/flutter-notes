import 'package:flutter/material.dart';
import '../models/note.dart';
import 'note_list.dart';

class AppSidebar extends StatelessWidget {
  final List<NoteMetadata> items;
  final int selectedIndex;
  final bool isUnsaved;
  final ValueChanged<int> onItemSelected;
  final TextEditingController searchController;
  final VoidCallback onSearchTriggered;

  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.isUnsaved,
    required this.onItemSelected,
    required this.searchController,
    required this.onSearchTriggered,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                valueListenable: searchController,
                builder: (context, value, _) {
                  return TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                searchController.clear();
                                onSearchTriggered();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => onSearchTriggered(),
                  );
                },
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey[300],
              indent: 16,
              endIndent: 16,
            ),
            Expanded(
              child: NoteList(
                items: items,
                selectedIndex: selectedIndex,
                isUnsaved: isUnsaved,
                onItemSelected: onItemSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
