import 'package:flutter/material.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/content/props.dart';
import 'package:nerdster/net/net_bar.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

enum Sort {
  // ratings('rating', PropType.rating),
  recommend('recommend', PropType.recommend),
  recentActivity('recent activity', PropType.recentActivity),
  comments('comments', PropType.numComments);

  const Sort(this.label, this.propType);
  final String label;
  final PropType propType;
}

enum Timeframe {
  all('all', null),
  year('past year', 365),
  month('past month', 30),
  week('past week', 7),
  day('today', 1);

  const Timeframe(this.label, this.days);
  final String label;
  final int? days;
}

class ContentBar extends StatefulWidget {
  const ContentBar({super.key});

  @override
  State<ContentBar> createState() => _ContentBarState();
}

class _ContentBarState extends State<ContentBar> {
  _ContentBarState() {
    ContentBase().addListener(listen);
  }

  void listen() {
    // This is to refresh MostTags.
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    ContentBase().removeListener(listen);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
              icon: const Icon(Icons.add),
              color: linkColor,
              tooltip: 'Submit',
              onPressed: () => submit(context)),
          const BarRefresh(),
          const FollowDropdown(),
          DropdownMenu<Sort>(
            initialSelection: contentBase.sort,
            requestFocusOnTap: true,
            label: const Text('Sort'),
            onSelected: (Sort? sort) {
              setState(() {
                if (sort != null) {
                  contentBase.sort = sort;
                }
              });
            },
            dropdownMenuEntries: Sort.values
                .map<DropdownMenuEntry<Sort>>((Sort sort) =>
                    DropdownMenuEntry<Sort>(value: sort, label: sort.label))
                .toList(),
          ),
          SizedBox(
              width: 100,
              child: DropdownMenu<ContentType>(
                initialSelection: contentBase.type,
                requestFocusOnTap: true,
                label: const Text('Type'),
                onSelected: (ContentType? type) {
                  setState(() {
                    if (type != null) {
                      contentBase.type = type;
                    }
                  });
                },
                dropdownMenuEntries: ContentType.values
                    .map<DropdownMenuEntry<ContentType>>((ContentType type) =>
                        DropdownMenuEntry<ContentType>(
                            value: type,
                            label: type.label,
                            leadingIcon: type.icon))
                    .toList(),
              )),
          SizedBox(
              width: 100,
              child: DropdownMenu<Timeframe>(
                initialSelection: contentBase.timeframe,
                requestFocusOnTap: true,
                label: const Text('Timeframe'),
                onSelected: (Timeframe? timeframe) {
                  setState(() {
                    if (timeframe != null) {
                      contentBase.timeframe = timeframe;
                    }
                  });
                },
                dropdownMenuEntries: Timeframe.values
                    .map<DropdownMenuEntry<Timeframe>>(
                        (Timeframe timeframe) => DropdownMenuEntry<Timeframe>(
                              value: timeframe,
                              label: timeframe.label,
                            ))
                    .toList(),
              )),
          SizedBox(
              width: 100,
              child: InputDecorator(
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  labelText: 'Censor',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.0)),
                ),
                child: Tooltip(
                  message:
                      'Allow folks you follow for net.one-of-us.censor to censor content you see',
                  child: Checkbox(
                      value: contentBase.censor,
                      onChanged: (censor) {
                        contentBase.censor = censor!;
                        setState(() => {});
                      }),
                ),
              )),
          IconButton(
              icon: const Icon(Icons.arrow_forward),
              color: linkColor,
              tooltip: 'Follow network view',
              onPressed: () async {
                await Comp.waitOnComps([followNet, keyLabels]);
                NetTreeView.show(context);
              }),
        ],
      ),
    );
  }
}
