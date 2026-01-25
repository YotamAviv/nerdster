import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/v2/model.dart';

class ContentBar extends StatelessWidget {
  final V2FeedController controller;
  final List<String> tags;

  const ContentBar({super.key, required this.controller, required this.tags});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSmall,
      builder: (context, small, _) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Sort
                Tooltip(
                  message: 'Sort order',
                  child: Row(
                    children: [
                      if (!small)
                        const Text('Sort: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<V2SortMode>(
                        value: controller.sortMode,
                        items: const [
                          DropdownMenuItem(value: V2SortMode.recentActivity, child: Text('Recent')),
                          DropdownMenuItem(value: V2SortMode.netLikes, child: Text('Net Likes')),
                          DropdownMenuItem(value: V2SortMode.mostComments, child: Text('Comments')),
                        ],
                        onChanged: (val) {
                          if (val != null) controller.sortMode = val;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Type Filter
                Tooltip(
                  message: 'Filter by type',
                  child: Row(
                    children: [
                      if (!small)
                        const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: controller.typeFilter ?? 'all',
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All')),
                          ...ContentType.values
                              .map((t) => DropdownMenuItem(value: t.name, child: Text(t.name))),
                        ],
                        onChanged: (val) {
                          controller.typeFilter = (val == 'all' ? null : val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Tag Filter
                Tooltip(
                  message: 'Filter by tag',
                  child: Row(
                    children: [
                      if (!small)
                        const Text('Tag: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: controller.tagFilter ?? '-',
                        items: [
                          const DropdownMenuItem(value: '-', child: Text('All')),
                          ...tags.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                        ],
                        onChanged: (val) {
                          controller.tagFilter = (val == '-' ? null : val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Dismissal Filter (formerly "Filter")
                Tooltip(
                  message: 'Filter dismissed content',
                  child: DropdownButton<DisFilterMode>(
                    value: controller.filterMode,
                    items: const [
                      DropdownMenuItem(value: DisFilterMode.my, child: Text('My Disses')),
                      DropdownMenuItem(value: DisFilterMode.pov, child: Text("PoV's Disses")),
                      DropdownMenuItem(
                          value: DisFilterMode.ignore, child: Text('Ignore Disses')),
                    ],
                    onChanged: (val) {
                      if (val != null) controller.filterMode = val;
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Censor Checkbox
                MyCheckbox(controller.enableCensorshipNotifier, 'Censor'),
              ],
            ),
          ),
        );
      },
    );
  }
}
