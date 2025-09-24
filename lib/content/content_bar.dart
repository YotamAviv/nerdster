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

enum DisOption { pov, mine, both, neither }

final ValueNotifier<bool> tagFlashNotifier = ValueNotifier<bool>(false);

class ContentBar extends StatefulWidget {
  const ContentBar({super.key});

  @override
  State<ContentBar> createState() => _ContentBarState();
}

class _ContentBarState extends State<ContentBar> {
  bool _highlightTagDropdown = false;
  final DisOption _selectedDisOption = DisOption.mine;

  _ContentBarState() {
    contentBase.addListener(listen);
    Setting.get(SettingType.tag).addListener(listen);
    tagFlashNotifier.addListener(flashListener);
  }

  void listen() async {
    await contentBase.waitUntilReady();
    setState(() {});
  }

  void flashListener() {
    if (tagFlashNotifier.value) _repeatFlash();
  }

  void _repeatFlash() {
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (mounted) setState(() => _highlightTagDropdown = true);
      });
      Future.delayed(Duration(milliseconds: i * 300 + 150), () {
        if (mounted) setState(() => _highlightTagDropdown = false);
      });
    }
  }

  @override
  void dispose() {
    contentBase.removeListener(listen);
    Setting.get(SettingType.tag).removeListener(listen);
    tagFlashNotifier.removeListener(flashListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isSignedIn = true; // Replace with auth check

    return Padding(
      padding: kTallPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            color: linkColor,
            tooltip: 'Submit',
            onPressed: () => submit(context),
          ),
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
            ),
          ),
          SizedBox(
            width: 100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: _highlightTagDropdown ? Colors.blue.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(4.0),
              ),
              padding: EdgeInsets.zero,
              child: DropdownMenu<String>(
                initialSelection: Setting.get(SettingType.tag).value,
                requestFocusOnTap: true,
                label: const Text('Tags'),
                onSelected: (String? tag) {
                  Setting.get(SettingType.tag).value = tag!;
                },
                dropdownMenuEntries: ['-', ...contentBase.mostTags]
                    .map<DropdownMenuEntry<String>>((String tag) => DropdownMenuEntry<String>(
                          value: tag,
                          label: tag,
                        ))
                    .toList(),
              ),
            ),
          ),
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
            ),
          ),
          SizedBox(
            height: 48,
            child: BorderedLabeledWidget(
              label: 'Censor',
              child: MyCheckbox(Setting.get<bool>(SettingType.censor).notifier, ''),
            ),
          ),
          SizedBox(
            width: 90,
            // height: 48,
            child: BorderedLabeledWidget(
              label: 'Dis',
              child: PopupMenuButton<DisOption>(
                initialValue: _selectedDisOption,
                onSelected: (DisOption value) => print('Selected: $value'),
                child: Text(
                  {
                    DisOption.pov: 'PoV\'s',
                    DisOption.mine: 'Mine',
                    DisOption.both: 'Both',
                    DisOption.neither: 'Ignored',
                  }[_selectedDisOption]!,
                  style: linkStyle,
                ),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<DisOption>>[
                  const PopupMenuItem<DisOption>(
                    value: DisOption.pov,
                    child: Text('Hide what PoV has dismissed'),
                  ),
                  PopupMenuItem<DisOption>(
                    value: DisOption.mine,
                    child: Text('Hide what I\'ve dismissed'),
                    enabled: true, // Replace with auth check
                  ),
                  const PopupMenuItem<DisOption>(
                    value: DisOption.both,
                    child: Text('Hide both what I\'ve dismissed and what PoV has dismissed'),
                  ),
                  const PopupMenuItem<DisOption>(
                    value: DisOption.neither,
                    child: Text('Ignore all dismiss statements'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<DisOption>(
                    enabled: false,
                    child: Text(
                      'TODO: Help text.. blah, blah, blah, blah, blah, blah...',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          padding: const EdgeInsets.only(top: 16, left: 8, right: 8, bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
          ),
          child: child,
        ),
        Positioned(
          top: 0,
          left: 3,
          child: Transform.translate(
            offset: const Offset(0, -8),
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
