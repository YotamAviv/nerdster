import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:convert';
import 'package:nerdster/config.dart';
import 'package:oneofus_common/keys.dart';
import 'package:nerdster/models/model.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/ui/key_icon.dart';
import 'package:nerdster/ui/key_info_view.dart';
import 'package:oneofus_common/trust_statement.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/logic/feed_controller.dart';
import 'package:nerdster/models/content_statement.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';
import 'package:nerdster/logic/follow_logic.dart';
import 'package:collection/collection.dart';
import 'package:nerdster/ui/dialogs/check_signed_in.dart';
import 'package:nerdster/ui/crypto_shield_button.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:url_launcher/url_launcher.dart';

class NodeDetails extends StatefulWidget {
  final IdentityKey identity;
  final FeedController controller;
  final ScrollController? scrollController;

  const NodeDetails({
    super.key,
    required this.identity,
    required this.controller,
    this.scrollController,
  });

  static Future<void> show(BuildContext context, IdentityKey identity, FeedController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NodeDetails(identity: identity, controller: controller),
    );
  }

  @override
  State<NodeDetails> createState() => _NodeDetailsState();
}

class _NodeDetailsState extends State<NodeDetails> {
  IdentityKey _resolveIdentity(IdentityKey key, FeedModel model) {
    if (model.trustGraph.isTrusted(key)) {
      return model.trustGraph.resolveIdentity(key);
    }
    return key;
  }

  IdentityKey _resolveDelegate(DelegateKey key, FeedModel model) {
    final identity = model.delegateResolver.getIdentityForDelegate(key);
    if (identity != null) {
      return _resolveIdentity(identity, model);
    }
    return _resolveIdentity(IdentityKey(key.value), model);
  }

  bool _isUpdating = false;
  Map<String, int> _originalContexts = {};
  String _originalComment = '';
  final Map<String, int> _pendingContexts = {};
  TextEditingController? _autocompleteController;
  final TextEditingController _commentController = TextEditingController();

  final ExpansibleController _followController = ExpansibleController();
  final ExpansibleController _keysController = ExpansibleController();
  final ExpansibleController _incomingController = ExpansibleController();
  final ExpansibleController _outgoingController = ExpansibleController();

  void _onExpansionChanged(bool expanded, ExpansibleController current) {
    if (expanded) {
      if (current != _followController) {
        try {
          _followController.collapse();
        } catch (_) {
          // Controller might not be attached if showing "This is you."
        }
      }
      if (current != _keysController) _keysController.collapse();
      if (current != _incomingController) _incomingController.collapse();
      if (current != _outgoingController) _outgoingController.collapse();
    }
  }

  FeedModel get model => widget.controller.value!;

  @override
  void initState() {
    super.initState();
    _initData();
    _commentController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    if (!mounted) return;

    if (!signInState.isSignedIn) return;

    final canonical = model.trustGraph.resolveIdentity(widget.identity);

    final myLiteralStatements =
        model.aggregation.myLiteralStatements[ContentKey(canonical.value)] ?? [];

    ContentStatement? priorStatement;
    for (var s in myLiteralStatements) {
      if (s.verb == ContentVerb.follow) {
        priorStatement = s;
        break;
      }
    }

    if (priorStatement != null) {
      setState(() {
        _originalComment = priorStatement!.comment ?? '';
        _commentController.text = _originalComment;
        if (priorStatement.contexts != null) {
          _originalContexts.clear();
          _pendingContexts.clear();
          priorStatement.contexts!.forEach((k, v) {
            if (v is int) {
              _originalContexts[k] = v;
              _pendingContexts[k] = v;
            }
          });
        }
      });
    }
  }

  bool get _hasChanges {
    final effectivePending = Map<String, int>.from(_pendingContexts)..removeWhere((k, v) => v == 0);
    final contextsChanged = !const MapEquality().equals(_originalContexts, effectivePending);
    final commentChanged = _commentController.text.trim() != _originalComment.trim();
    return contextsChanged || commentChanged;
  }

  @override
  Widget build(BuildContext context) {
    final Labeler labeler = model.labeler;
    // Labeler label/getLabel takes string or key? currently string
    // Assuming labeler has getAllLabels returning List<String> or similar?

    // I didn't implement getAllLabels in new Labeler!
    // I should implement it or remove this feature.
    // Let's implement basic label for now.

    final TrustGraph tg = model.trustGraph;
    // getEquivalenceGroup returns List<IdentityKey> ??
    // Let's check TrustGraph.
    // It has getEquivalenceGroups() returning Map.
    // We can compute it:
    // This is expensive to scan all Replacements?
    // Maybe just show canonical.

    final delegates = labeler.delegateResolver
            ?.getDelegatesForIdentity(widget.identity)
            .map((d) => d.value)
            .toList() ??
        [];
    final String fcontext = model.fcontext;

    // Resolve identity to ensure we lookup correctly in graphs
    final IdentityKey canonicalIdentity = _resolveIdentity(widget.identity, model);

    // My own (identity-layer) trust or block statement for this identity, independent of PoV.
    final TrustStatement? myTrustStatement = signInState.isSignedIn
        ? (model.myTrustStatements[canonicalIdentity] ?? model.myTrustStatements[widget.identity])
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(labeler, canonicalIdentity),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFollowContextsSection(),
                  const Divider(),
                  _buildKeysSection(tg, labeler, delegates),
                  const Divider(),
                  if (fcontext == kFollowContextIdentity) ...[
                    _buildIdentityDetails(canonicalIdentity, model),
                    _buildIdentityOutgoing(canonicalIdentity, model),
                  ] else if (fcontext == kFollowContextNerdster) ...[
                    _buildNerdsterDetails(canonicalIdentity, model),
                    _buildNerdsterOutgoing(canonicalIdentity, model),
                  ] else ...[
                    _buildContextDetails(canonicalIdentity, model, fcontext),
                    _buildContextOutgoing(canonicalIdentity, model, fcontext),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CryptoShieldButton(json: myTrustStatement?.json, labeler: labeler),
                  const SizedBox(width: 4),
                  
                  Builder(builder: (context) {
                    final bool canAct = signInState.isSignedIn && signInState.identity != widget.identity.value;
                    
                    final bool canTrust = canAct && myTrustStatement?.verb != TrustVerb.trust;
                    final String trustTip = !canAct ? 'Must be signed in as a different identity' 
                                          : (!canTrust ? 'You already vouch for this identity' : 'Vouch for this identity');

                    final bool canBlock = canAct && myTrustStatement?.verb != TrustVerb.block;
                    final String blockTip = !canAct ? 'Must be signed in as a different identity'
                                          : (!canBlock ? 'You already block this identity' : 'Block this identity');

                    final bool canClear = canAct && myTrustStatement != null;
                    final String clearTip = !canAct ? 'Must be signed in as a different identity'
                                          : (!canClear ? 'No statement exists to clear' : 'Clear your trust/block for this identity');

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: trustTip,
                          child: IconButton(
                            onPressed: canTrust ? () => _onTrustPressed(context, widget.identity) : null,
                            icon: Icon(
                              // Solid = currently vouching. Outline = available action.
                              myTrustStatement?.verb == TrustVerb.trust ? Icons.check_circle : Icons.check_circle_outline,
                              color: Colors.green,  // always green; IconButton dims interaction but we keep color.
                            ),
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: blockTip,
                          child: IconButton(
                            onPressed: canBlock ? () => _passIntention(context, 'block', widget.identity) : null,
                            icon: Icon(
                              // Solid = currently blocking. Outline = available action.
                              myTrustStatement?.verb == TrustVerb.block ? Icons.delete : Icons.delete_outline,
                              color: Colors.red,  // always red.
                            ),
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: clearTip,
                          child: IconButton(
                            onPressed: canClear ? () => _passIntention(context, 'clear', widget.identity) : null,
                            icon: Icon(
                              // Outline = has statement to clear (enabled). Solid = nothing to clear (disabled).
                              canClear ? Icons.cancel_outlined : Icons.cancel,
                              color: canClear ? Colors.black : Colors.grey,
                            ),
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: _buildActions(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Labeler labeler, IdentityKey identity) {
    final identityStr = identity.value;
    final primaryLabel = labeler.getLabel(identityStr);
    final allLabels = labeler.getAllLabels(identity);
    final otherLabels = allLabels.where((l) => l != primaryLabel).toList();

    return Builder(builder: (context) {
      TapDownDetails? tapDetails;
      return InkWell(
        onTapDown: (details) => tapDetails = details,
        onDoubleTap: () {
          const qrSize = 250.0;
          const qrH = 375.0;
          final pos = tapDetails?.globalPosition ?? Offset.zero;
          final screenSize = MediaQuery.of(context).size;
          double left = pos.dx;
          double top = pos.dy;
          if (left + qrSize > screenSize.width) left = pos.dx - qrSize;
          if (top + qrH > screenSize.height) top = pos.dy - qrH;
          if (left < 0) left = 0;
          if (top < 0) top = 0;
          showGeneralDialog<void>(
            context: context,
            barrierDismissible: true,
            barrierLabel: '',
            barrierColor: Colors.black12,
            transitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: SizedBox(
                      width: qrSize,
                      height: qrH,
                      child: JsonQrDisplay(identityStr),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        onTap: () {
          final FedKey fedKey = FedKey.find(IdentityKey(identityStr))!;
          KeyInfoView.show(context, identityStr, (fedKey.endpoint['url'] as String?) ?? kNativeUrl,
              details: tapDetails,
              source: widget.controller.trustSource,
              labeler: labeler,
              constraints: const BoxConstraints(maxWidth: 600));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(primaryLabel),
                  if (otherLabels.isNotEmpty)
                    Text('(${otherLabels.join(', ')})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.qr_code, size: 24, color: Colors.blue),
          ],
        ),
      );
    });
  }

  /// Passes a trust/block/clear intention to your identity app.
  /// For keymeid/oneOfUsNet sign-ins the app is known to be available; open the universal link.
  Future<void> _passIntention(BuildContext context, String verb, IdentityKey identity) async {
    final String key = identity.value;
    final Json? identityJson = FedKey.find(identity)?.pubKeyJson;
    if (identityJson == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot load identity details')));
      }
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PassIntentionDialog(
        verb: verb,
        identityKey: key,
        identityJson: identityJson,
        method: signInState.signInMethod,
      ),
    );
  }

  /// Trust shows an informational dialog explaining that vouching is an in-person action.
  /// There is no proceed path — vouching cannot be initiated from here.
  Future<void> _onTrustPressed(BuildContext context, IdentityKey identity) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vouch for this identity'),
        content: const Text(
          'Vouching means you personally know this person and that you carried out the vouch through an in-person meeting '
          'or another secure channel, NOT because of what you see on the Nerdster.\n\n'
          'Vouch using your identity app instead.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      if (widget.identity != model.trustGraph.pov)
        TextButton(
          onPressed: () {
            // Updating global POV
            Navigator.pop(context); // Close sheet/dialog first
            signInState.pov = widget.identity.value;
            widget.controller.refresh();
          },
          child: const Text('Set as PoV'),
        ),
      TextButton(
        onPressed: () async {
          if (_hasChanges) {
            final bool? shouldClose = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Unsaved Changes'),
                content: const Text(
                    'You have unsaved follow/block changes. Are you sure you want to discard them?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
            if (shouldClose == true) {
              if (context.mounted) Navigator.of(context).pop();
            }
          } else {
            Navigator.of(context).pop();
          }
        },
        child: const Text('Close'),
      )
    ];
  }

  Widget _buildKeysSection(TrustGraph tg, Labeler labeler, List<String> delegates) {
    return ExpansionTile(
      controller: _keysController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _keysController),
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Keys', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child:
              Text('Identity Keys:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        ...tg.getEquivalenceGroup(widget.identity).map((IdentityKey equivKey) {
          final equivIdentityToken = equivKey.value;
          final bool isCanonical = equivKey == widget.identity;
          final String equivIdentityLabel = labeler.getLabel(equivIdentityToken);
          // Replaced keys are considered revoked for visualization
          final status = isCanonical ? KeyStatus.active : KeyStatus.revoked;

          return Builder(builder: (context) {
            TapDownDetails? tapDetails;
            return Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTapDown: (details) => tapDetails = details,
                onTap: () {
                  final FedKey? hk = FedKey.find(IdentityKey(equivIdentityToken));
                  KeyInfoView.show(context, equivIdentityToken, (hk?.endpoint['url'] as String?) ?? kNativeUrl,
                      details: tapDetails,
                      source: widget.controller.trustSource,
                      labeler: labeler,
                      constraints: const BoxConstraints(maxWidth: 600));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KeyIcon(
                        type: KeyType.identity,
                        status: status,
                        presence: KeyPresence.known,
                      ),
                      const SizedBox(width: 8),
                      Text('$equivIdentityLabel ${isCanonical ? "" : "(Replaced)"}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isCanonical ? Colors.black : Colors.grey,
                              decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ),
            );
          });
        }),
        if (delegates.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child:
                Text('Delegate Keys:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          ...delegates.map((d) {
            final String delegateLabel = labeler.getLabel(d);
            final bool isMyDelegate = signInState.delegate == d;

            final isRevoked =
                labeler.delegateResolver?.getConstraintForDelegate(DelegateKey(d)) != null;
            final status = isRevoked ? KeyStatus.revoked : KeyStatus.active;

            return Builder(builder: (context) {
              TapDownDetails? tapDetails;
              return Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTapDown: (details) => tapDetails = details,
                  onTap: () => KeyInfoView.show(context, d, FirebaseConfig.contentUrl,
                      details: tapDetails,
                      source: widget.controller.contentSource,
                      labeler: labeler,
                      constraints: const BoxConstraints(maxWidth: 600)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KeyIcon(
                          type: KeyType.delegate,
                          status: status,
                          presence: isMyDelegate ? KeyPresence.owned : KeyPresence.known,
                        ),
                        const SizedBox(width: 8),
                        Text(delegateLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: isRevoked ? Colors.grey : Colors.blue,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors
                                    .blue)), // Keep link underline color if possible, or grey? Blue usually implies link.
                      ],
                    ),
                  ),
                ),
              );
            });
          }),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildFollowContextsSection() {
    if (signInState.isSignedIn && signInState.identity == widget.identity.value) {
      return const Text("This is you.", style: TextStyle(fontStyle: FontStyle.italic));
    }

    final label = model.labeler.getLabel(widget.identity.value);

    return ExpansionTile(
      controller: _followController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _followController),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text('How I follow/block $label',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: _hasChanges
          ? const Text('Unsaved changes pending...',
              style: TextStyle(color: Colors.orange, fontSize: 11, fontStyle: FontStyle.italic))
          : null,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        if (_hasChanges)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _saveChanges,
              icon: _isUpdating
                  ? const SizedBox(
                      width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.publish, size: 16),
              label: const Text('Publish Changes', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        if (_pendingContexts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text('Not following in any context.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
          ),
        ..._pendingContexts.entries.map((e) => _buildContextRow(e.key, e.value)),
        const SizedBox(height: 12),
        _buildAddContextRow(),
        const SizedBox(height: 12),
        const Text('Comment (Optional):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: _commentController,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'Add a reason for following/blocking...',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.all(8),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildContextRow(String contextName, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
              child: Text(contextName,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: -1, label: Text('Block'), icon: Icon(Icons.block, size: 14)),
              ButtonSegment(value: 0, label: Text('Neutral'), icon: Icon(Icons.remove, size: 14)),
              ButtonSegment(value: 1, label: Text('Follow'), icon: Icon(Icons.check, size: 14)),
            ],
            selected: {value == 0 ? 0 : (value > 0 ? 1 : -1)},
            onSelectionChanged: (Set<int> newSelection) async {
              if ((await checkSignedIn(context, trustGraph: model.trustGraph)) != true) return;
              setState(() {
                final val = newSelection.first;
                _pendingContexts[contextName] = val;
              });
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 10)),
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 4)),
            ),
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }

  Widget _buildAddContextRow() {
    final List<String> suggestions = [
      kFollowContextNerdster,
      'social',
      'family',
      'news',
      'music',
      'tech'
    ].where((c) => !_pendingContexts.containsKey(c)).toList();

    return Row(
      children: [
        const Text('Add: ', style: TextStyle(fontSize: 12)),
        Expanded(
          child: Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return suggestions;
              }
              return suggestions.where((String option) {
                return option.contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) async {
              if ((await checkSignedIn(context, trustGraph: model.trustGraph)) != true) return;
              setState(() {
                _pendingContexts[selection] = 0; // Default to neutral
                _autocompleteController?.clear();
              });
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              _autocompleteController = controller;
              return SizedBox(
                height: 30,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    hintText: 'Context (e.g. nerd)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (String value) async {
                    if (value.isNotEmpty) {
                      if ((await checkSignedIn(context, trustGraph: model.trustGraph)) != true)
                        return;
                      setState(() {
                        _pendingContexts[value] = 0; // Default to neutral
                        controller.clear();
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isUpdating = true);
    try {
      final signer = signInState.signer;
      if (signer == null) return;

      final contextsToSave = Map<String, int>.from(_pendingContexts)
        ..removeWhere((key, value) => value == 0);

      final json = ContentStatement.make(
        signInState.delegatePublicKeyJson!,
        ContentVerb.follow,
        widget.identity.value,
        contexts: contextsToSave,
        comment: _commentController.text.trim(),
      );

      await widget.controller.push(json, signer, context: context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow preferences updated.')),
        );

        setState(() {
          _pendingContexts.removeWhere((key, value) => value == 0);
          _originalContexts = Map.of(_pendingContexts);
          _originalComment = _commentController.text.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Widget _buildIdentityOutgoing(IdentityKey identity, FeedModel model) {
    final TrustGraph tg = model.trustGraph;
    final List<TrustStatement> allStatements = tg.edges[identity] ?? [];

    final List<TrustStatement> statements =
        allStatements.where((s) => s.verb == TrustVerb.trust).toList();

    return ExpansionTile(
      controller: _outgoingController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _outgoingController),
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Outgoing Vouches',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        if (statements.isEmpty) const Text('None'),
        ...statements.map((s) => _buildStatementTile(s, model, isOutgoing: true)),
      ],
    );
  }

  Widget _buildContextOutgoing(IdentityKey identity, FeedModel model, String context) {
    final fn = model.followNetwork;

    final List<ContentStatement> statements = fn.edges.values
        .expand((l) => l)
        .where((s) => _resolveIdentity(IdentityKey(s.iKey.value), model) == identity)
        .where((s) => s.contexts?.containsKey(context) == true)
        .toList();

    return ExpansionTile(
      controller: _outgoingController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _outgoingController),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text('Outgoing Follows ($context)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        if (statements.isEmpty) const Text('None'),
        ...statements
            .map((s) => _buildStatementTile(s, model, fcontext: context, isOutgoing: true)),
      ],
    );
  }

  Widget _buildNerdsterOutgoing(IdentityKey identity, FeedModel model) {
    final fn = model.followNetwork;
    final tg = model.trustGraph;

    // 1. Explicit Follows (Outgoing)
    final List<ContentStatement> explicitStatements = fn.edges.values
        .expand((l) => l)
        .where(
            (s) => _resolveIdentity(IdentityKey(s.iKey.value), model) == identity) // Check issuer
        .where((s) => s.contexts?.containsKey(kFollowContextNerdster) == true)
        .toList();

    // 2. Implicit Follows (Trust) (Outgoing)
    // "Who does THIS identity trust?" -> tg.edges[identity]
    final List<TrustStatement> trustStatements =
        (tg.edges[identity] ?? []).where((s) => s.verb == TrustVerb.trust).toList();

    // Filter implicitly trusted that are NOT explicitly followed
    // Note: This logic is slightly different than incoming. Incoming we dedup based on issuer.
    // Here we are the issuer. We check if we have an explicit follow for the *subject*.

    final explicitSubjects =
        explicitStatements.map((s) => _resolveIdentity(IdentityKey(s.subjectToken), model)).toSet();

    final List<TrustStatement> implicitStatements = trustStatements.where((s) {
      final subject = _resolveIdentity(IdentityKey(s.subjectToken), model);
      return !explicitSubjects.contains(subject);
    }).toList();

    return ExpansionTile(
      controller: _outgoingController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _outgoingController),
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Outgoing Follows (<nerdster>)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        const Text(
          'Includes explicit follows AND implicit follows derived from Trust.',
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),
        const Text('Explicit:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (explicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
        ...explicitStatements.map((s) =>
            _buildStatementTile(s, model, fcontext: kFollowContextNerdster, isOutgoing: true)),
        const SizedBox(height: 10),
        const Text('Implicit (Trust):', style: TextStyle(fontWeight: FontWeight.bold)),
        if (implicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
        ...implicitStatements.map((s) => _buildStatementTile(s, model, isOutgoing: true)),
      ],
    );
  }

  Widget _buildIdentityDetails(IdentityKey identity, FeedModel model) {
    final tg = model.trustGraph;

    final List<TrustStatement> statements = tg.edges.values
        .expand((l) => l)
        .where((s) => s.verb == TrustVerb.trust) // Only show actual vouches
        .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
        .toList();

    return ExpansionTile(
      controller: _incomingController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _incomingController),
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Incoming Vouches',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        if (statements.isEmpty) const Text('None'),
        ...statements.map((s) => _buildStatementTile(s, model)),
      ],
    );
  }

  Widget _buildContextDetails(IdentityKey identity, FeedModel model, String context) {
    final fn = model.followNetwork;

    final List<ContentStatement> statements = fn.edges.values
        .expand((l) => l)
        .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
        .where((s) => s.contexts?.containsKey(context) == true)
        .toList();

    return ExpansionTile(
      controller: _incomingController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _incomingController),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text('Incoming Follows ($context)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        if (statements.isEmpty) const Text('None'),
        ...statements.map((s) => _buildStatementTile(s, model, fcontext: context)),
      ],
    );
  }

  Widget _buildNerdsterDetails(IdentityKey identity, FeedModel model) {
    final fn = model.followNetwork;
    final tg = model.trustGraph;

    // 1. Explicit Follows
    final List<ContentStatement> explicitStatements = fn.edges.values
        .expand((l) => l)
        .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
        .where((s) => s.contexts?.containsKey(kFollowContextNerdster) == true)
        .toList();

    final explicitIssuers =
        explicitStatements.map((s) => _resolveDelegate(DelegateKey(s.iKey.value), model)).toSet();

    // 2. Implicit Follows (Trust)
    final List<TrustStatement> implicitStatements = tg.edges.values
        .expand((l) => l)
        .where((s) => s.verb == TrustVerb.trust) // Only trust implies follow
        .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
        .where((s) {
      final issuer = _resolveDelegate(DelegateKey(s.iKey.value), model);
      return !explicitIssuers.contains(issuer);
    }).toList();

    return ExpansionTile(
      controller: _incomingController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _incomingController),
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Incoming Follows (<nerdster>)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        const Text(
          'Includes explicit follows AND implicit follows derived from Trust (unless overridden).',
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),
        const Text('Explicit:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (explicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
        ...explicitStatements
            .map((s) => _buildStatementTile(s, model, fcontext: kFollowContextNerdster)),
        const SizedBox(height: 10),
        const Text('Implicit (Trust):', style: TextStyle(fontWeight: FontWeight.bold)),
        if (implicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
        ...implicitStatements.map((s) => _buildStatementTile(s, model)),
      ],
    );
  }

  Widget _buildStatementTile(dynamic s, FeedModel model,
      {String? fcontext, bool isOutgoing = false}) {
    final labeler = model.labeler;
    // s can be TrustStatement or ContentStatement.

    IdentityKey relevantKey;
    if (isOutgoing) {
      // For outgoing, we care about the SUBJECT
      if (s is TrustStatement) {
        relevantKey = IdentityKey(s.subjectToken);
      } else if (s is ContentStatement) {
        relevantKey = IdentityKey(s.subjectToken);
      } else {
        relevantKey = IdentityKey('?');
      }
    } else {
      // For incoming, we care about the ISSUER
      if (s is TrustStatement) {
        relevantKey = s.iKey;
      } else if (s is ContentStatement) {
        relevantKey = IdentityKey(s.iToken);
      } else {
        relevantKey = IdentityKey('?');
      }
    }

    final keyLabel = labeler.getLabel(_resolveIdentity(relevantKey, model).value);
    String verbLabel = s is TrustStatement ? s.verb.label : (s as ContentStatement).verb.label;
    bool isBlock = false;

    if (s is ContentStatement && s.verb.label == 'follow' && fcontext != null) {
      final val = s.contexts?[fcontext];
      if (val != null) {
        final num v = val is num ? val : num.tryParse(val.toString()) ?? 0;
        if (v < 0) {
          verbLabel = '-follow';
          isBlock = true;
        }
      }
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$keyLabel ('),
                  TextSpan(
                    text: verbLabel,
                    style: TextStyle(color: isBlock ? Colors.red : null),
                  ),
                  const TextSpan(text: ')'),
                ],
              ),
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
          CryptoShieldButton(json: s.json, labeler: labeler),
        ],
      ),
    );
  }
}

class _PassIntentionDialog extends StatelessWidget {
  final String verb;
  final String identityKey;
  final Json identityJson;
  final SignInMethod? method;

  const _PassIntentionDialog({required this.verb, required this.identityKey, required this.identityJson, this.method});

  /// Encode pubKeyJson as a URL-safe base64 fragment, same format as vouch links.
  String _fragment() {
    final jsonStr = jsonEncode(identityJson);
    return base64Url.encode(utf8.encode(jsonStr));
  }

  @override
  Widget build(BuildContext context) {
    final Size availableSize = MediaQuery.of(context).size;
    final double width = min(availableSize.width * 0.9, 400);

    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final bool isMobileDevice = isIOS || isAndroid;

    Widget content;
    final String title = '${verb[0].toUpperCase()}${verb.substring(1)} identity';
    final String fragment = _fragment();

    if (method == SignInMethod.oneOfUsNet || (method == null && isMobileDevice)) {
       // Use https:// universal link with fragment payload — server never sees the key.
       final Uri uri = Uri.parse('https://one-of-us.net/$verb#$fragment');
       content = ListTile(
         leading: const Icon(Icons.link),
         title: const Text('https://one-of-us.net/...'),
         subtitle: const Text('Use your identity app'),
         onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
       );
    } else if (method == SignInMethod.keymeid) {
       // Use keymeid:// custom scheme with fragment payload.
       final Uri uri = Uri.parse('keymeid://$verb#$fragment');
       content = ListTile(
         leading: const Icon(Icons.link),
         title: const Text('keymeid://...'),
         subtitle: const Text('Use your identity app'),
         onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
       );
    } else {
       // Desktop / unknown — show QR of the raw key JSON for scanning.
       content = Column(
         mainAxisSize: MainAxisSize.min,
         children: [
            const Text('Scan this code with your identity app.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            JsonQrDisplay(identityJson, interpret: ValueNotifier(false)),
         ]
       );
    }

    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                    width: width,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      content,
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                        ]
                      )
                    ])))));
  }
}
