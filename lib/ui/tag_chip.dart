import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/equivalence_statement.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/ui/tag_util.dart';
import 'package:oneofus_common/jsonish.dart' show Json;

/// A tag chip for content cards. Shows `#tag` with an optional expand caret
/// when the tag has related or equivalent peers. Tapping the caret opens an
/// overlay popup with `≠` / `!~` action buttons. When showCrypto is on and
/// provenance statements exist, a shield button is shown to inspect them.
class TagChip extends StatefulWidget {
  final String tag;
  final ContentAggregation aggregation;
  final FeedController controller;
  final VoidCallback? onTap;

  const TagChip({
    super.key,
    required this.tag,
    required this.aggregation,
    required this.controller,
    this.onTap,
  });

  @override
  State<TagChip> createState() => _TagChipState();
}

class _TagChipState extends State<TagChip> {
  OverlayEntry? _overlayEntry;
  OverlayEntry? _provenanceOverlay;
  OverlayEntry? _jsonOverlay;
  final _caretKey = GlobalKey();

  String get _canon => widget.aggregation.tagEquivalence[widget.tag] ?? widget.tag;

  List<String> get _equivalents => widget.aggregation.tagEquivalence.entries
      .where((e) => e.value == _canon && e.key != _canon)
      .map((e) => e.key)
      .toList()
    ..sort();

  List<String> get _peers =>
      widget.aggregation.tagRelate.peersOf(_canon).toList()..sort();

  bool get _hasChildren => _equivalents.isNotEmpty || _peers.isNotEmpty;
  bool get _canEdit => signInState.signer != null;
  bool get _isOpen => _overlayEntry != null;

  List<EquivalenceStatement> get _groupStatements {
    final groupTags = {_canon, ..._equivalents};
    final seen = <String>{};
    final result = <EquivalenceStatement>[];
    for (final tag in groupTags) {
      for (final s in widget.aggregation.tagEquivalenceStatements[tag] ?? []) {
        if (seen.add(s.token)) result.add(s);
      }
    }
    return result;
  }

  @override
  void dispose() {
    _jsonOverlay?.remove();
    _provenanceOverlay?.remove();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleOverlay() => _isOpen ? _closeOverlay() : _openOverlay();

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  void _openOverlay() {
    final renderBox = _caretKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final pos = renderBox.localToGlobal(Offset.zero);
    final caretHeight = renderBox.size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    const popupWidth = 200.0;
    final left = (pos.dx).clamp(8.0, screenWidth - popupWidth - 8);

    _overlayEntry = OverlayEntry(builder: (_) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeOverlay,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: pos.dy + caretHeight + 4,
            width: popupWidth,
            child: _TagGroupPopup(
              canon: _canon,
              equivalents: _equivalents,
              peers: _peers,
              canEdit: _canEdit,
              onDontEquate: _handleDontEquate,
              onDontRelate: _handleDontRelate,
            ),
          ),
        ]),
      );
    });

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  Future<void> _handleDontEquate(String equivalent, String canonical) async {
    if (!_canEdit) return;
    if (!await _showConfirm('"$equivalent" is not an equivalent of "$canonical"')) return;
    if (!mounted) return;
    await widget.controller.pushEquivalence(equivalent, canonical,
        verb: EquivalenceVerb.dontEquate, context: context);
    _closeOverlay();
  }

  Future<void> _handleDontRelate(String tagA, String tagB) async {
    if (!_canEdit) return;
    if (!await _showConfirm('"$tagA" is not related to "$tagB"')) return;
    if (!mounted) return;
    await widget.controller.pushEquivalence(tagA, tagB,
        verb: EquivalenceVerb.dontRelate, context: context);
    _closeOverlay();
  }

  Future<bool> _showConfirm(String message) async {
    final overlayEntry = _overlayEntry;
    if (overlayEntry == null) return false;
    final completer = Completer<bool>();
    late OverlayEntry dialogEntry;

    void close(bool confirmed) {
      dialogEntry.remove();
      if (!completer.isCompleted) completer.complete(confirmed);
    }

    dialogEntry = OverlayEntry(builder: (_) => Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => close(false),
            child: const SizedBox.expand(),
          ),
        ),
        Center(child: ConfirmDialog(message: message, onResult: close)),
      ]),
    ));

    Overlay.of(context).insert(dialogEntry, above: overlayEntry);
    return completer.future;
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

  void _openJsonOverlay(Json? json, Labeler labeler, Offset tapPosition) {
    if (json == null) return;
    _removeJsonOverlay();
    _jsonOverlay = openJsonOverlay(
      context: context,
      json: json,
      labeler: labeler,
      tapPosition: tapPosition,
      onDismiss: _removeJsonOverlay,
    );
    Overlay.of(context).insert(_jsonOverlay!);
  }

  void _openProvenance() {
    _removeProvenanceOverlay();
    final stmts = _groupStatements;
    final myToken = signInState.delegate;
    final canClear = _canEdit;
    _provenanceOverlay = OverlayEntry(builder: (_) {
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _removeProvenanceOverlay,
          ),
        ),
        TagProvenanceDialog(
          canonical: _canon,
          statements: stmts,
          onShowJson: _openJsonOverlay,
          myDelegateToken: canClear ? myToken : null,
          onClear: canClear ? _handleClearEquivalence : null,
        ),
      ]);
    });
    Overlay.of(context).insert(_provenanceOverlay!);
  }

  void _handleClearEquivalence(EquivalenceStatement s) {
    _removeProvenanceOverlay();
    final ctx = context;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.pushEquivalence(s.equivalent, s.canonical,
            verb: EquivalenceVerb.clear, context: ctx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayTag = widget.tag.startsWith('#') ? widget.tag : '#${widget.tag}';
    final groupStmts = _groupStatements;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: widget.onTap,
          child: Text(displayTag, style: const TextStyle(color: Colors.blue, fontSize: 13)),
        ),
        if (_hasChildren)
          GestureDetector(
            key: _caretKey,
            onTap: _toggleOverlay,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(
                _isOpen ? Icons.expand_less : Icons.expand_more,
                size: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        if (groupStmts.isNotEmpty)
          GroupShieldButton(onTap: _openProvenance),
      ],
      ),
    );
  }
}

class _TagGroupPopup extends StatelessWidget {
  final String canon;
  final List<String> equivalents;
  final List<String> peers;
  final bool canEdit;
  final void Function(String eq, String canon) onDontEquate;
  final void Function(String a, String b) onDontRelate;

  const _TagGroupPopup({
    required this.canon,
    required this.equivalents,
    required this.peers,
    required this.canEdit,
    required this.onDontEquate,
    required this.onDontRelate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...equivalents.map((eq) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(eq,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
                ),
                if (canEdit)
                  DontEquateButton(onPressed: () => onDontEquate(eq, canon)),
              ],
            ),
          )),
          ...peers.map((peer) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(peer,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.green.shade700)),
                ),
                if (canEdit)
                  DontRelateButton(onPressed: () => onDontRelate(canon, peer)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
