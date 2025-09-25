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

  final String label;
  final Duration? duration;

  const Timeframe(this.label, this.duration);
}

enum DisOption {
  pov("PoV's", "PoV's"),
  mine('Mine', "Mine"),
  either('Either', "Hide content dismissed by either me or PoV"),
  ignore('Ignore', 'Ignore all dismiss statements');

  final String short;
  final String long;

  const DisOption(this.short, this.long);
}

/// DEFER: REFACTOR:
final helpStyle = TextStyle(
  fontSize: 12,
  color: Colors.grey.shade800,
  fontStyle: FontStyle.italic,
);

/// DEFER: REFACTOR:
/// maybe support disabling, help text, etc...
class PopupMenuHelpItem<T> extends PopupMenuEntry<T> {
  final Widget child;

  const PopupMenuHelpItem({required this.child});

  @override
  double get height => 0; // no enforced height

  @override
  bool represents(T? value) => false;

  @override
  State<PopupMenuHelpItem<T>> createState() => _PopupMenuHelpItemState<T>();
}

class _PopupMenuHelpItemState<T> extends State<PopupMenuHelpItem<T>> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: widget.child,
    );
  }
}

final ValueNotifier<bool> tagFlashNotifier = ValueNotifier<bool>(false);

class ContentBar extends StatefulWidget {
  const ContentBar({super.key});

  @override
  State<ContentBar> createState() => _ContentBarState();
}

class _ContentBarState extends State<ContentBar> {
  bool _highlightTagDropdown = false;

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
    Setting disSetting = Setting.get<String>(SettingType.dis);
    DisOption disOption = DisOption.values.byName(disSetting.value);

    return Padding(
      padding: kTallPadding,
      child: Row(
        // mainAxisSize: MainAxisSize.min,
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
          DropdownMenu<ContentType>(
            width: 90,
            initialSelection: contentBase.type,
            requestFocusOnTap: true,
            label: const Text('Type'),
            onSelected: (ContentType? type) => setState(() => contentBase.type = type!),
            dropdownMenuEntries: ContentType.values
                .map<DropdownMenuEntry<ContentType>>((ContentType type) =>
                    DropdownMenuEntry<ContentType>(
                        value: type, label: type.label, leadingIcon: Icon(type.iconDatas.$1)))
                .toList(),
          ),
          AnimatedContainer(
            width: 90,
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
              onSelected: (String? tag) => Setting.get(SettingType.tag).value = tag!,
              dropdownMenuEntries: ['-', ...contentBase.mostTags]
                  .map<DropdownMenuEntry<String>>(
                      (String tag) => DropdownMenuEntry<String>(value: tag, label: tag))
                  .toList(),
            ),
          ),
          DropdownMenu<Timeframe>(
            initialSelection: contentBase.timeframe,
            requestFocusOnTap: true,
            label: const Text('Timeframe'),
            onSelected: (Timeframe? timeframe) =>
                setState(() => contentBase.timeframe = timeframe!),
            dropdownMenuEntries: Timeframe.values
                .map<DropdownMenuEntry<Timeframe>>((Timeframe timeframe) =>
                    DropdownMenuEntry<Timeframe>(value: timeframe, label: timeframe.label))
                .toList(),
          ),
          SizedBox(
            height: 48,
            child: BorderedLabeledWidget(
                label: 'Censor',
                child: MyCheckbox(Setting.get<bool>(SettingType.censor).notifier, null)),
          ),
          BorderedLabeledWidget(
              label: 'Dis',
              child: PopupMenuButton<DisOption>(
                initialValue: disOption,
                onSelected: (value) => setState(() => disSetting.value = value.name),
                child: Text(disOption.short, style: linkStyle),
                itemBuilder: (context) => [
                  PopupMenuHelpItem<DisOption>(
                    child: Text(
                      "Who's disses should be respected:",
                      style: helpStyle,
                    ),
                  ),
                  const PopupMenuDivider(height: 4),
                  ...DisOption.values.map(
                    (opt) => PopupMenuItem<DisOption>(
                      value: opt,
                      child: Text(
                        opt.long,
                        style: opt == DisOption.mine && !b(signInState.identity)
                            ? TextStyle(color: Theme.of(context).disabledColor)
                            : null,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(height: 4),
                  PopupMenuHelpItem<DisOption>(
                    child: Text(
                      '''Reacting to content with a "Dis" (Dismiss) means you don't want to see it again (not necessarily that you dislike it).
When browsing content from other points of view (PoV), you can choose to honor their disses, yours, both, or neither.''',
                      style: helpStyle,
                    ),
                  ),
                ],
              )),
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
