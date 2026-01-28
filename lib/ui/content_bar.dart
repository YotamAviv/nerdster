import 'package:flutter/material.dart';
import 'package:nerdster/app.dart';
import 'package:nerdster/content/content_types.dart';

import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/models/model.dart';

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

                // Dismissal Filter
                Tooltip(
                  message: "Hide content I've dismissed",
                  child: Row(
                    children: [
                      Checkbox(
                        value: controller.filterMode == DisFilterMode.my,
                        activeColor: Colors.brown,
                        side: const BorderSide(color: Colors.brown, width: 2.0),
                        onChanged: (val) {
                          controller.filterMode =
                              (val == true) ? DisFilterMode.my : DisFilterMode.ignore;
                        },
                      ),
                      if (!small) const Text('Dismiss'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Censor Checkbox
                ValueListenableBuilder<bool>(
                  valueListenable: controller.enableCensorshipNotifier,
                  builder: (context, enabled, _) {
                    return Tooltip(
                      message: 'Filter censored content',
                      child: Row(
                        children: [
                          Checkbox(
                            value: enabled,
                            activeColor: Colors.red,
                            side: const BorderSide(color: Colors.red, width: 2.0),
                            onChanged: (val) {
                              controller.enableCensorshipNotifier.value = val ?? false;
                            },
                          ),
                          if (!small) ...[
                            const Text('Censor'),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
