import 'package:flutter/material.dart';
import '../models/note.dart';
import 'note_list_item.dart';

class NoteList extends StatefulWidget {
  final List<NoteMetadata> items;
  final int selectedIndex;
  final bool isUnsaved;
  final ValueChanged<int> onItemSelected;

  const NoteList({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.isUnsaved = false,
    required this.onItemSelected,
  });

  @override
  State<NoteList> createState() => _NoteListState();
}

class _NoteListState extends State<NoteList> {
  late final ScrollController _scrollController;
  final ValueNotifier<bool> _isScrollingNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _isScrollingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _isScrollingNotifier.value = true;
        } else if (notification is ScrollEndNotification) {
          _isScrollingNotifier.value = false;
        }
        return false;
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: _isScrollingNotifier,
        builder: (context, isScrolling, child) {
          return ListView.separated(
            controller: _scrollController,
            physics: const HeavyScrollPhysics(parent: BouncingScrollPhysics()),
            cacheExtent: 500,
            itemCount: widget.items.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey[300],
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final metadata = widget.items[index];
              return NoteListItem(
                key: ValueKey(metadata.id),
                metadata: metadata,
                isSelected: index == widget.selectedIndex,
                isUnsaved: index == widget.selectedIndex && widget.isUnsaved,
                isScrolling: isScrolling,
                onTap: () => widget.onItemSelected(index),
              );
            },
          );
        },
      ),
    );
  }
}

class HeavyScrollPhysics extends BouncingScrollPhysics {
  const HeavyScrollPhysics({super.parent});

  @override
  HeavyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HeavyScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Significantly reduce velocity to simulate higher friction/mass
    // This makes the scroll "stop" much faster after a fling
    if (velocity.abs() > 0) {
      return super.createBallisticSimulation(position, velocity * 0.9);
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
