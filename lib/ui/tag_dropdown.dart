import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nerdster/equivalence/equivalence.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/equivalence_statement.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster_common/ui/json_interpreter.dart';
import 'package:oneofus_common/jsonish.dart' show Json;
import 'package:oneofus_common/ui/json_display.dart';
import 'package:nerdster/ui/tag_util.dart';

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
  final Equivalence tagRelate;
  final Map<String, List<EquivalenceStatement>> tagEquivalenceStatements;
  final String? activeFilter;
  final ValueChanged<String?> onFilterChanged;
  final FeedController? controller;

  const TagDropdownButton({
    super.key,
    required this.mostTags,
    required this.tagEquivalence,
    required this.tagRelate,
    required this.tagEquivalenceStatements,
    required this.activeFilter,
    required this.onFilterChanged,
    this.controller,
  });

  @override
  State<TagDropdownButton> createState() => _TagDropdownButtonState();
}

class _TagDropdownButtonState extends State<TagDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;
  OverlayEntry? _provenanceOverlay;
  OverlayEntry? _jsonOverlay;
  String? _expanded;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeJsonOverlay() {
    _jsonOverlay?.remove();
    _jsonOverlay = null;
  }

  void _removeProvenanceOverlay() {
    _removeJsonOverlay();
    _provenanceOverlay?.remove();
    _provenanceOverlay = null;
  }

  void _removeOverlay() {
    _removeProvenanceOverlay();
    _overlay?.remove();
    _overlay = null;
  }

  void _openJsonOverlay(Json? json, Labeler labeler, Offset tapPosition) {
    if (json == null) return;
    _removeJsonOverlay();
    final size = MediaQuery.of(context).size;
    final dw = (size.width - 16).clamp(0.0, 420.0);
    final dh = (size.height - 16).clamp(0.0, 390.0);
    double left = tapPosition.dx;
    double top = tapPosition.dy;
    if (left + dw > size.width) left = tapPosition.dx - dw;
    if (top + dh > size.height) top = tapPosition.dy - dh;
    if (left < 0) left = 0;
    if (top < 0) top = 0;
    _jsonOverlay = OverlayEntry(builder: (_) {
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _removeJsonOverlay,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: dw,
                height: dh,
                child: JsonDisplay(json, interpreter: JsonInterpreter(labeler)),
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_jsonOverlay!);
  }

  void _handleClearEquivalence(EquivalenceStatement s) {
    final controller = widget.controller;
    if (controller == null || signInState.signer == null) return;
    _removeProvenanceOverlay();
    final ctx = context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.pushEquivalence(s.equivalent, s.canonical, verb: EquivalenceVerb.clear, context: ctx);
    });
  }

  void _openProvenance(String canonical, List<EquivalenceStatement> statements) {
    _removeProvenanceOverlay();
    final myToken = signInState.delegate;
    final canClear = widget.controller != null && signInState.signer != null;
    _provenanceOverlay = OverlayEntry(builder: (_) {
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _removeProvenanceOverlay,
          ),
        ),
        TagProvenanceDialog(
          canonical: canonical,
          statements: statements,
          onShowJson: _openJsonOverlay,
          myDelegateToken: canClear ? myToken : null,
          onClear: canClear ? _handleClearEquivalence : null,
        ),
      ]);
    });
    Overlay.of(context).insert(_provenanceOverlay!);
  }

  @override
  void didUpdateWidget(TagDropdownButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlay != null &&
        (oldWidget.tagEquivalence != widget.tagEquivalence ||
            oldWidget.tagRelate != widget.tagRelate ||
            oldWidget.mostTags != widget.mostTags ||
            oldWidget.tagEquivalenceStatements != widget.tagEquivalenceStatements)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _overlay?.markNeedsBuild();
      });
    }
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

  void _handleEquate(String equivalent, String canonical, BuildContext ctx) {
    final controller = widget.controller;
    if (controller == null || signInState.signer == null) return;
    if (widget.activeFilter == equivalent) {
      widget.onFilterChanged(canonical);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.pushEquivalence(equivalent, canonical, verb: EquivalenceVerb.equate, context: ctx);
    });
  }

  void _handleDontEquate(String equivalent, String canonical, BuildContext ctx) {
    final controller = widget.controller;
    if (controller == null || signInState.signer == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await _showConfirm('"$equivalent" is not an equivalent of "$canonical"')) return;
      if (!ctx.mounted) return;
      await controller.pushEquivalence(equivalent, canonical, verb: EquivalenceVerb.dontEquate, context: ctx);
    });
  }

  void _handleRelate(String tagA, String tagB, BuildContext ctx) {
    final controller = widget.controller;
    if (controller == null || signInState.signer == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.pushEquivalence(tagA, tagB, verb: EquivalenceVerb.relate, context: ctx);
    });
  }

  void _handleDontRelate(String tagA, String tagB, BuildContext ctx) {
    final controller = widget.controller;
    if (controller == null || signInState.signer == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await _showConfirm('"$tagA" is not related to "$tagB"')) return;
      if (!ctx.mounted) return;
      await controller.pushEquivalence(tagA, tagB, verb: EquivalenceVerb.dontRelate, context: ctx);
    });
  }

  Future<bool> _showConfirm(String message) async {
    final dropdownEntry = _overlay;
    if (dropdownEntry == null) return false;

    final completer = Completer<bool>();
    late OverlayEntry dialogEntry;

    void close(bool confirmed) {
      dialogEntry.remove();
      if (!completer.isCompleted) completer.complete(confirmed);
    }

    dialogEntry = OverlayEntry(builder: (_) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => close(false),
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: ConfirmDialog(message: message, onResult: close),
          ),
        ]),
      );
    });

    Overlay.of(context).insert(dialogEntry, above: dropdownEntry);
    return completer.future;
  }

  Future<void> _handleDrop(String sourceTag, String targetTag) async {
    final controller = widget.controller;
    if (controller == null || signInState.signer == null) return;
    final dropdownEntry = _overlay;
    if (dropdownEntry == null) return;

    final completer = Completer<bool?>();
    late OverlayEntry dialogEntry;

    void close(bool? result) {
      dialogEntry.remove();
      if (!completer.isCompleted) completer.complete(result);
    }

    dialogEntry = OverlayEntry(builder: (_) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => close(null),
              child: const SizedBox.expand(), // transparent tap-catcher; no dimming
            ),
          ),
          Center(
            child: _RelateEquateDialog(
              sourceTag: sourceTag,
              targetTag: targetTag,
              onResult: close,
            ),
          ),
        ]),
      );
    });

    // Insert above the dropdown so the dialog is guaranteed to paint on top.
    Overlay.of(context).insert(dialogEntry, above: dropdownEntry);

    final bool? equate = await completer.future;
    if (equate == null || !mounted) return;
    if (equate) {
      _handleEquate(sourceTag, targetTag, context);
    } else {
      _handleRelate(sourceTag, targetTag, context);
    }
  }

  OverlayEntry _buildOverlay() {
    final RenderBox? buttonBox = context.findRenderObject() as RenderBox?;
    final double buttonLeftX = buttonBox?.localToGlobal(Offset.zero).dx ?? 0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double panelWidth = (screenWidth - 16).clamp(200.0, 260.0);
    final double rightEdge = buttonLeftX + panelWidth;
    final double dx = rightEdge > screenWidth - 8 ? -(rightEdge - (screenWidth - 8)) : 0.0;

    return OverlayEntry(builder: (ctx) {
      final groups = buildTagGroups(widget.mostTags, widget.tagEquivalence);
      final canEdit = widget.controller != null && signInState.signer != null;
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
          offset: Offset(dx, 36),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: panelWidth,
                height: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _TagPanel(
                    groups: groups,
                    tagRelate: widget.tagRelate,
                    expanded: _expanded,
                    activeFilter: widget.activeFilter,
                    tagEquivalenceStatements: widget.tagEquivalenceStatements,
                    canEdit: canEdit,
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
                    onDrop: (source, target) => _handleDrop(source, target),
                    onDontEquate: (eq, canon) => _handleDontEquate(eq, canon, ctx),
                    onDontRelate: (a, b) => _handleDontRelate(a, b, ctx),
                    onShield: _openProvenance,
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

class _TagPanel extends StatefulWidget {
  final Map<String, Set<String>> groups;
  final Equivalence tagRelate;
  final Map<String, List<EquivalenceStatement>> tagEquivalenceStatements;
  final String? expanded;
  final String? activeFilter;
  final bool canEdit;
  final void Function(String canon) onToggleExpand;
  final void Function(String canon) onSelectFilter;
  final void Function(String source, String target) onDrop;
  final void Function(String equivalent, String canonical) onDontEquate;
  final void Function(String tagA, String tagB) onDontRelate;
  final void Function(String canonical, List<EquivalenceStatement> statements) onShield;

  const _TagPanel({
    required this.groups,
    required this.tagRelate,
    required this.tagEquivalenceStatements,
    required this.expanded,
    required this.activeFilter,
    required this.canEdit,
    required this.onToggleExpand,
    required this.onSelectFilter,
    required this.onDrop,
    required this.onDontEquate,
    required this.onDontRelate,
    required this.onShield,
  });

  @override
  State<_TagPanel> createState() => _TagPanelState();
}

class _TagPanelState extends State<_TagPanel> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling(double direction) {
    if (_scrollTimer?.isActive ?? false) return;
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scrollController.hasClients) return;
      final current = _scrollController.offset;
      final max = _scrollController.position.maxScrollExtent;
      final next = (current + direction * 5).clamp(0.0, max);
      if (next == current) _stopScrolling();
      _scrollController.jumpTo(next);
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  /// Gathers all equivalence statements for every tag in the group (deduplicated).
  List<EquivalenceStatement> _groupStatements(Set<String> groupTags) {
    final seen = <String>{};
    final result = <EquivalenceStatement>[];
    for (final tag in groupTags) {
      for (final s in widget.tagEquivalenceStatements[tag] ?? []) {
        if (seen.add(s.token)) result.add(s);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.groups.entries.toList();
    return Stack(children: [
      ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          _TagRow(
            tag: '',
            label: 'All',
            isActive: widget.activeFilter == null,
            canEdit: false,
            onTap: () => widget.onSelectFilter(''),
            onDrop: null,
          ),
          ...entries.map((e) {
            final canon = e.key;
            final equivalents = (e.value.toList()..remove(canon)..sort());
            final peers = widget.tagRelate.peersOf(canon).toList()..sort();
            final hasChildren = equivalents.isNotEmpty || peers.isNotEmpty;
            final isExpanded = widget.expanded == canon;
            final groupStmts = _groupStatements(e.value);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TagRow(
                  tag: canon,
                  label: canon,
                  isActive: widget.activeFilter == canon,
                  canEdit: widget.canEdit,
                  onTap: () => widget.onSelectFilter(canon),
                  hasCaret: hasChildren,
                  isExpanded: isExpanded,
                  onCaret: () => widget.onToggleExpand(canon),
                  onDrop: widget.canEdit ? (sourceTag) => widget.onDrop(sourceTag, canon) : null,
                  onShield: groupStmts.isNotEmpty
                      ? () => widget.onShield(canon, groupStmts)
                      : null,
                ),
                if (isExpanded && hasChildren)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Equivalent children — light red, ≠ button, tap to filter
                        ...equivalents.map((eq) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: InkWell(
                                  onTap: () => widget.onSelectFilter(eq),
                                  child: Text(eq,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
                                ),
                              ),
                              if (widget.canEdit)
                                DontEquateButton(onPressed: () => widget.onDontEquate(eq, canon)),
                            ],
                          ),
                        )),
                        // Related peers — light green, !~ button, tap to filter
                        ...peers.map((peer) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: InkWell(
                                  onTap: () => widget.onSelectFilter(peer),
                                  child: Text(peer,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: Colors.green.shade700)),
                                ),
                              ),
                              if (widget.canEdit)
                                DontRelateButton(onPressed: () => widget.onDontRelate(canon, peer)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      // Scroll zones: invisible DragTarget strips at top and bottom.
      // onWillAcceptWithDetails returns false so drops still reach the row targets below.
      Positioned(
        top: 0, left: 0, right: 0, height: 32,
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) => false,
          onMove: (_) => _startScrolling(-1),
          onLeave: (_) => _stopScrolling(),
          builder: (_, __, ___) => const SizedBox.expand(),
        ),
      ),
      Positioned(
        bottom: 0, left: 0, right: 0, height: 32,
        child: DragTarget<String>(
          onWillAcceptWithDetails: (_) => false,
          onMove: (_) => _startScrolling(1),
          onLeave: (_) => _stopScrolling(),
          builder: (_, __, ___) => const SizedBox.expand(),
        ),
      ),
    ]);
  }
}

// ─── Tag Row ──────────────────────────────────────────────────────────────────

class _TagRow extends StatelessWidget {
  final String tag;
  final String label;
  final bool isActive;
  final bool canEdit;
  final VoidCallback onTap;
  final bool hasCaret;
  final bool isExpanded;
  final VoidCallback? onCaret;
  final void Function(String sourceTag)? onDrop;
  final VoidCallback? onShield;

  const _TagRow({
    required this.tag,
    required this.label,
    required this.isActive,
    required this.canEdit,
    required this.onTap,
    this.hasCaret = false,
    this.isExpanded = false,
    this.onCaret,
    this.onDrop,
    this.onShield,
  });

  Widget _buildDragFeedback() => IgnorePointer(
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(tag, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // The drag handle and the text tap area are intentionally separate gesture zones
    // so that pressing the handle never triggers the filter-select tap.
    Widget rowContent = Row(
      children: [
        if (canEdit && tag.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Draggable<String>(
              data: tag,
              feedback: _buildDragFeedback(),
              childWhenDragging:
                  Icon(Icons.drag_indicator, size: 14, color: Colors.grey.shade200),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {}, // absorb tap so it doesn't reach the row's InkWell
                child: Icon(Icons.drag_indicator, size: 14, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Container(
              color: isActive ? Colors.blue.shade50 : null,
              padding: EdgeInsets.only(
                left: (canEdit && tag.isNotEmpty) ? 4 : 12,
                right: 4,
                top: 8,
                bottom: 8,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.blue.shade700 : Colors.black87,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
        if (hasCaret)
          GestureDetector(
            onTap: onCaret,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        if (onShield != null)
          GroupShieldButton(onTap: onShield!),
      ],
    );

    if (onDrop == null) return rowContent;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != tag,
      onAcceptWithDetails: (details) => onDrop!(details.data),
      builder: (ctx, candidateData, _) {
        final hovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: hovered
              ? BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: rowContent,
        );
      },
    );
  }
}

// ─── Relate-or-equate dialog (shown on drag-drop) ─────────────────────────────

class _RelateEquateDialog extends StatefulWidget {
  final String sourceTag;
  final String targetTag;
  final void Function(bool?) onResult;

  const _RelateEquateDialog({
    required this.sourceTag,
    required this.targetTag,
    required this.onResult,
  });

  @override
  State<_RelateEquateDialog> createState() => _RelateEquateDialogState();
}

class _RelateEquateDialogState extends State<_RelateEquateDialog> {
  bool _equate = false;

  Widget _row(bool checked, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: checked,
                  onChanged: (_) => onTap(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(!_equate, '"${widget.sourceTag}" is related to "${widget.targetTag}"',
              () => setState(() => _equate = false)),
          _row(_equate, '"${widget.sourceTag}" is an equivalent of "${widget.targetTag}"',
              () => setState(() => _equate = true)),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              textStyle: const TextStyle(fontSize: 13)),
          onPressed: () => widget.onResult(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              textStyle: const TextStyle(fontSize: 13)),
          onPressed: () => widget.onResult(_equate),
          child: const Text('Ok'),
        ),
      ],
    );
  }
}
