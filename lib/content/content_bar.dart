import 'package:flutter/material.dart';
import 'package:nerdster/content/content_base.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/content/props.dart';
import 'package:nerdster/oneofus/ui/my_checkbox.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/prefs.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/util_ui.dart';

enum Sort {
  // ratings('rating', PropType.rating),
  like('like', PropType.like),
  recentActivity('recent activity', PropType.recentActivity),
  comments('comments', PropType.numComments);

  const Sort(this.label, this.propType);
  final String label;
  final PropType propType;
}

enum Timeframe {
  all('all', null),
  year('past year', Duration(days: 365)),
  month('past month', Duration(days: 30)),
  week('past week', Duration(days: 7)),
  day('today', Duration(days: 1));

  const Timeframe(this.label, this.duration);
  final String label;
  final Duration? duration;
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
      padding: kTallPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
              icon: const Icon(Icons.add),
              color: linkColor,
              tooltip: 'Submit',
              onPressed: () => submit(context)),
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
                .map<DropdownMenuEntry<Sort>>(
                    (Sort sort) => DropdownMenuEntry<Sort>(value: sort, label: sort.label))
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
                            value: type, label: type.label, leadingIcon: Icon(type.iconDatas.$1)))
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
                    contentBase.timeframe = timeframe!;
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
            height: 48,
            child: BorderedLabeledWidget(
                label: 'Censor',
                child: MyCheckbox(Setting.get<bool>(SettingType.censor).notifier, '')),
          )
        ],
      ),
    );
  }
}

class BorderedLabeledWidget extends StatelessWidget {
  final Widget child;
  final String label;

  const BorderedLabeledWidget({super.key, required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.only(
              top: 16, left: 8, right: 8, bottom: 8), // Adjust padding to accommodate label height
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
          ),
          child: child,
        ),
        Positioned(
          top: 0,
          left: 3,
          child: Transform.translate(
            offset: const Offset(0, -8), // Translate label up to align with border
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Text(label, style: Theme.of(context).textTheme.labelMedium),
            ),
          ),
        ),
      ],
    );
  }
}
