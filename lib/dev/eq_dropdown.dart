// Prototype: equivalence editor inside a custom overlay dropdown.
//
// Run via:
//   flutter run -d chrome -t lib/dev/eq_dropdown.dart

import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    home: EqDropdownDemo(),
    debugShowCheckedModeBanner: false,
  ));
}

final _initialGroups = <String, Set<String>>{
  'bikes': {'bikes', 'cycling'},
  'js': {'js'},
  'bicycle': {'bicycle'},
  'two-wheels': {'two-wheels'},
  'python': {'python'},
  'snake': {'snake'},
  'javascript': {'javascript'},
  'programming': {'programming'},
  'coding': {'coding'},
};

// ─── Top-level demo shell ────────────────────────────────────────────────────

class EqDropdownDemo extends StatefulWidget {
  const EqDropdownDemo({super.key});
  @override
  State<EqDropdownDemo> createState() => _EqDropdownDemoState();
}

class _EqDropdownDemoState extends State<EqDropdownDemo> {
  String? _activeFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equivalence Dropdown')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EqDropdownButton(
              activeFilter: _activeFilter,
              onFilterChanged: (f) => setState(() => _activeFilter = f),
            ),
            const SizedBox(height: 32),
            if (_activeFilter != null)
              Text('Filtering by: $_activeFilter',
                  style: const TextStyle(fontSize: 16))
            else
              const Text('No filter active',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─── Dropdown button + overlay ───────────────────────────────────────────────

class EqDropdownButton extends StatefulWidget {
  final String? activeFilter;
  final ValueChanged<String?> onFilterChanged;

  const EqDropdownButton({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  State<EqDropdownButton> createState() => _EqDropdownButtonState();
}

class _EqDropdownButtonState extends State<EqDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  bool _dragging = false;

  late Map<String, Set<String>> _groups;
  String? _expanded;

  @override
  void initState() {
    super.initState();
    _groups = {for (final e in _initialGroups.entries) e.key: Set.of(e.value)};
  }

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
    return OverlayEntry(builder: (context) {
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (!_dragging) {
                _removeOverlay();
                if (mounted) setState(() {});
              }
            },
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 280,
                height: 360,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _EqPanel(
                    groups: _groups,
                    expanded: _expanded,
                    activeFilter: widget.activeFilter,
                    onDrop: (token, canon) {
                      if (_groups.containsKey(token)) {
                        _groups[canon]!.addAll(_groups.remove(token)!);
                      } else {
                        final members = _groups.remove(token) ?? {token};
                        _groups.putIfAbsent(canon, () => {canon});
                        _groups[canon]!.addAll(members);
                      }
                      _expanded = canon;
                      _rebuild();
                    },
                    onRemove: (token, canon) {
                      _groups[canon]!.remove(token);
                      _groups[token] = {token};
                      _rebuild();
                    },
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
                    onDragStart: () => _dragging = true,
                    onDragEnd: () => _dragging = false,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.activeFilter != null
                ? Colors.blue.shade100
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
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

// ─── Panel contents ──────────────────────────────────────────────────────────

class _EqPanel extends StatelessWidget {
  final Map<String, Set<String>> groups;
  final String? expanded;
  final String? activeFilter;
  final void Function(String token, String canon) onDrop;
  final void Function(String token, String canon) onRemove;
  final void Function(String canon) onToggleExpand;
  final void Function(String canon) onSelectFilter;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _EqPanel({
    required this.groups,
    required this.expanded,
    required this.activeFilter,
    required this.onDrop,
    required this.onRemove,
    required this.onToggleExpand,
    required this.onSelectFilter,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final e = sorted[i];
        return _PanelRow(
          canonical: e.key,
          members: e.value,
          isExpanded: expanded == e.key,
          isActive: activeFilter == e.key,
          onDrop: (token) => onDrop(token, e.key),
          onRemove: (token) => onRemove(token, e.key),
          onToggleExpand: () => onToggleExpand(e.key),
          onSelectFilter: () => onSelectFilter(e.key),
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
        );
      },
    );
  }
}

// ─── Single row ──────────────────────────────────────────────────────────────

class _PanelRow extends StatelessWidget {
  final String canonical;
  final Set<String> members;
  final bool isExpanded;
  final bool isActive;
  final ValueChanged<String> onDrop;
  final ValueChanged<String> onRemove;
  final VoidCallback onToggleExpand;
  final VoidCallback onSelectFilter;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  const _PanelRow({
    required this.canonical,
    required this.members,
    required this.isExpanded,
    required this.isActive,
    required this.onDrop,
    required this.onRemove,
    required this.onToggleExpand,
    required this.onSelectFilter,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final hasMembers = members.length > 1;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != canonical,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidateData, _) {
        final hovering = candidateData.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Draggable<String>(
              data: canonical,
              onDragStarted: onDragStart,
              onDragEnd: (_) => onDragEnd(),
              onDraggableCanceled: (_, __) => onDragEnd(),
              // Feedback is unconstrained — must not use double.infinity width.
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: _RowHeader(
                    canonical: canonical,
                    count: members.length,
                    hovering: false,
                    isActive: false,
                    isExpanded: false,
                    fillWidth: false,
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _RowHeader(
                  canonical: canonical,
                  count: members.length,
                  hovering: false,
                  isActive: isActive,
                  isExpanded: isExpanded,
                  fillWidth: true,
                ),
              ),
              child: _RowHeader(
                canonical: canonical,
                count: members.length,
                hovering: hovering,
                isActive: isActive,
                isExpanded: isExpanded,
                fillWidth: true,
                onSelectFilter: onSelectFilter,
                onToggleExpand: hasMembers ? onToggleExpand : null,
              ),
            ),
            if (hasMembers && isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (members.toList()..remove(canonical)..sort())
                      .map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(m,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54)),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => onRemove(m),
                                  child: Icon(Icons.close,
                                      size: 14,
                                      color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Row header ───────────────────────────────────────────────────────────────

class _RowHeader extends StatelessWidget {
  final String canonical;
  final int count;
  final bool hovering;
  final bool isActive;
  final bool isExpanded;
  final bool fillWidth;
  final VoidCallback? onSelectFilter;
  final VoidCallback? onToggleExpand;

  const _RowHeader({
    required this.canonical,
    required this.count,
    required this.hovering,
    required this.isActive,
    required this.isExpanded,
    required this.fillWidth,
    this.onSelectFilter,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = hovering
        ? Colors.blue.shade100
        : isActive
            ? Colors.blue.shade50
            : Colors.transparent;

    final textWidget = GestureDetector(
      onTap: onSelectFilter,
      child: Text(
        canonical,
        style: TextStyle(
          color: isActive ? Colors.blue.shade700 : Colors.black87,
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: fillWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: bg,
      child: Row(
        mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (fillWidth) Expanded(child: textWidget) else textWidget,
          if (count > 1) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onToggleExpand,
              child: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
