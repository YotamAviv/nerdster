import 'package:flutter/material.dart';

/// Builds the display groups for the tag dropdown:
/// canonical → Set of all equivalent tags (including itself).
/// Order is determined by [mostTags] (frequency-descending).
Map<String, Set<String>> buildTagGroups(
    List<String> mostTags, Map<String, String> tagEquivalence) {
  final Map<String, Set<String>> groups = {};
  for (final tag in mostTags) {
    groups.putIfAbsent(tag, () => {tag});
  }
  for (final entry in tagEquivalence.entries) {
    if (entry.key != entry.value) {
      groups.putIfAbsent(entry.value, () => {entry.value}).add(entry.key);
    }
  }
  return groups;
}

class TagDropdownButton extends StatefulWidget {
  final List<String> mostTags;
  final Map<String, String> tagEquivalence;
  final String? activeFilter;
  final ValueChanged<String?> onFilterChanged;

  const TagDropdownButton({
    super.key,
    required this.mostTags,
    required this.tagEquivalence,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  State<TagDropdownButton> createState() => _TagDropdownButtonState();
}

class _TagDropdownButtonState extends State<TagDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  String? _expanded;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggleOverlay() {
    if (_overlay != null) {
      _removeOverlay();
      setState(() {});
      return;
    }
    _overlay = _buildOverlay();
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  void _rebuild() => _overlay?.markNeedsBuild();

  OverlayEntry _buildOverlay() {
    return OverlayEntry(builder: (ctx) {
      final groups = buildTagGroups(widget.mostTags, widget.tagEquivalence);
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              _removeOverlay();
              if (mounted) setState(() {});
            },
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 36),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 240,
                height: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _TagPanel(
                    groups: groups,
                    expanded: _expanded,
                    activeFilter: widget.activeFilter,
                    onToggleExpand: (canon) {
                      _expanded = _expanded == canon ? null : canon;
                      _rebuild();
                    },
                    onSelectFilter: (canon) {
                      widget.onFilterChanged(
                          widget.activeFilter == canon ? null : canon);
                      _removeOverlay();
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final open = _overlay != null;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleOverlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.activeFilter != null
                ? Colors.blue.shade100
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: open ? Colors.blue : Colors.grey.shade400,
              width: open ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.activeFilter ?? 'Tags',
                style: TextStyle(
                  fontWeight: widget.activeFilter != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Panel ────────────────────────────────────────────────────────────────────

class _TagPanel extends StatelessWidget {
  final Map<String, Set<String>> groups;
  final String? expanded;
  final String? activeFilter;
  final void Function(String canon) onToggleExpand;
  final void Function(String canon) onSelectFilter;

  const _TagPanel({
    required this.groups,
    required this.expanded,
    required this.activeFilter,
    required this.onToggleExpand,
    required this.onSelectFilter,
  });

  @override
  Widget build(BuildContext context) {
    final entries = groups.entries.toList();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // "All" row
        _TagRow(
          label: 'All',
          isActive: activeFilter == null,
          onTap: () => onSelectFilter(''),
        ),
        ...entries.map((e) {
          final equivalents = (e.value.toList()..remove(e.key)..sort());
          final isExpanded = expanded == e.key;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TagRow(
                label: e.key,
                isActive: activeFilter == e.key,
                onTap: () => onSelectFilter(e.key),
                hasCaret: equivalents.isNotEmpty,
                isExpanded: isExpanded,
                onCaret: () => onToggleExpand(e.key),
              ),
              if (isExpanded && equivalents.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: equivalents
                        .map((m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                m,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool hasCaret;
  final bool isExpanded;
  final VoidCallback? onCaret;

  const _TagRow({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.hasCaret = false,
    this.isExpanded = false,
    this.onCaret,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isActive ? Colors.blue.shade50 : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.blue.shade700 : Colors.black87,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (hasCaret)
              GestureDetector(
                onTap: onCaret,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
