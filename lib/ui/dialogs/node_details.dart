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
import 'package:oneofus_common/ui/json_qr_display.dart';
import 'package:nerdster/logic/follow_logic.dart';
import 'package:collection/collection.dart';
import 'package:nerdster/ui/dialogs/check_signed_in.dart';
import 'package:nerdster/ui/crypto_shield_button.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:url_launcher/url_launcher.dart';

class NodeDetails extends StatefulWidget {
  final IdentityKey identity;
  final FeedController controller;

  const NodeDetails({
    super.key,
    required this.identity,
    required this.controller,
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
  final Map<String, int> _pendingContexts = {};
  TextEditingController? _autocompleteController;
  int? _followsTab;
  int? _keysTab;

  final ExpansibleController _followController = ExpansibleController();
  final ExpansibleController _keysController = ExpansibleController();
  final ExpansibleController _followsVouchesController = ExpansibleController();

  void _onExpansionChanged(bool expanded, ExpansibleController current) {
    if (expanded) {
      if (current == _keysController && _keysTab == null) setState(() => _keysTab = 0);
      if (current == _followsVouchesController && _followsTab == null) setState(() => _followsTab = 0);
      if (current != _followController) {
        try { _followController.collapse(); } catch (_) {}
      }
      if (current != _keysController) {
        _keysController.collapse();
        setState(() => _keysTab = null);
      }
      if (current != _followsVouchesController) {
        _followsVouchesController.collapse();
        setState(() => _followsTab = null);
      }
    } else {
      if (current == _keysController) setState(() => _keysTab = null);
      if (current == _followsVouchesController) setState(() => _followsTab = null);
    }
  }

  FeedModel get model => widget.controller.value!;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    if (!mounted) return;

    if (!signInState.hasIdentity) return;

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
        if (priorStatement!.contexts != null) {
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
    return !const MapEquality().equals(_originalContexts, effectivePending);
  }

  @override
  Widget build(BuildContext context) {
    final Labeler labeler = model.labeler;

    final delegates = labeler.delegateResolver
            ?.getDelegatesForIdentity(widget.identity)
            .map((d) => d.value)
            .toList() ??
        [];
    final String fcontext = model.fcontext;

    final IdentityKey canonicalIdentity = _resolveIdentity(widget.identity, model);

    final TrustStatement? myTrustStatement = signInState.hasIdentity
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
          _buildHeader(labeler, canonicalIdentity, delegates),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFollowContextsSection(),
                  const Divider(),
                  _buildKeysSection(model.trustGraph, labeler, delegates),
                  const Divider(),
                  _buildFollowsVouchesSection(canonicalIdentity, model, fcontext),
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
                    final bool canAct = signInState.hasIdentity && signInState.identity.value != widget.identity.value;

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
                          child: InkWell(
                            onTap: canTrust ? () => _onTrustPressed(context, widget.identity) : null,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                myTrustStatement?.verb == TrustVerb.trust ? Icons.check_circle : Icons.check_circle_outline,
                                color: Colors.green,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: blockTip,
                          child: InkWell(
                            onTap: canBlock ? () => _passIntention(context, 'block', widget.identity) : null,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                myTrustStatement?.verb == TrustVerb.block ? Icons.delete : Icons.delete_outline,
                                color: Colors.red,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: clearTip,
                          child: InkWell(
                            onTap: canClear ? () => _passIntention(context, 'clear', widget.identity) : null,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                canClear ? Icons.cancel_outlined : Icons.cancel,
                                color: canClear ? Colors.black : Colors.grey,
                                size: 22,
                              ),
                            ),
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

  Widget _buildHeader(Labeler labeler, IdentityKey identity, List<String> delegates) {
    final identityStr = identity.value;
    final primaryLabel = labeler.getLabel(identityStr);
    final allLabels = labeler.getAllLabels(identity);
    final otherLabels = allLabels.where((l) => l != primaryLabel).toList();
    final bool isPov = widget.identity == model.trustGraph.pov;

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
          KeyInfoView.show(context, identityStr, FirebaseConfig.resolveUrl((fedKey.endpoint['url'] as String?) ?? kNativeUrl),
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
                  Text(primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (otherLabels.isNotEmpty)
                    Text('(${otherLabels.join(', ')})',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey)),
                ],
              ),
            ),
            if (!isPov || delegates.any((d) =>
                labeler.delegateResolver?.getDomainForDelegate(DelegateKey(d)) == 'hablotengo.com')) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isPov)
                    GestureDetector(
                      onTap: () async {
                        if (_hasChanges) {
                          await showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Unpublished Changes'),
                              content: const Text('Save your follow changes before setting this as PoV.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        if (context.mounted) Navigator.pop(context);
                        signInState.pov = widget.identity.value;
                        await widget.controller.refresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Set as PoV', style: TextStyle(fontSize: 11, color: Colors.blue)),
                      ),
                    ),
                  if (delegates.any((d) =>
                      labeler.delegateResolver?.getDomainForDelegate(DelegateKey(d)) == 'hablotengo.com')) ...[
                    if (!isPov) const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        final bool emulator = fireChoice == FireChoice.emulator;
                        final base = emulator ? 'http://localhost:8770/' : 'https://hablotengo.com/app';
                        final uri = Uri.parse(base).replace(queryParameters: {
                          if (emulator) 'fire': 'emulator',
                          'target': widget.identity.value,
                        });
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.contact_page, size: 13, color: Colors.blue),
                          Text('HabloTengo', style: TextStyle(fontSize: 11, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Future<void> _passIntention(BuildContext context, String verb, IdentityKey identity) async {
    if (verb == 'block') {
      final IdentityKey canonical = _resolveIdentity(identity, model);
      final TrustStatement? myStatement = signInState.hasIdentity
          ? (model.myTrustStatements[canonical] ?? model.myTrustStatements[identity])
          : null;
      final bool alreadyVouched = myStatement?.verb == TrustVerb.trust;

      if (!context.mounted) return;
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Blocking is Harsh!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You\'d be removing this identity from existing.',
              ),
              const SizedBox(height: 12),
              const Text(
                'If this is a person whose content you don\'t appreciate, '
                'use the follow/block settings to block him for <nerdster> context.',
              ),
              if (alreadyVouched) ...[
                const SizedBox(height: 12),
                const Text(
                  'You\'ve vouched for this person. Consider just clearing your vouch instead.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block anyway', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

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

  Future<void> _onTrustPressed(BuildContext context, IdentityKey identity) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vouch using your identity app instead'),
        content: const Text(
          'Vouching means you personally know this person and that you carried out the vouch through an in-person meeting '
          'or another secure channel, NOT because of what you see on the Nerdster.\n\n',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      TextButton(
        onPressed: _hasChanges ? (_isUpdating ? null : _saveChanges) : null,
        child: _isUpdating
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Publish'),
      ),
      TextButton(
        onPressed: () async {
          if (_hasChanges) {
            final bool? shouldClose = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Unpublished Changes'),
                content: const Text('You have unpublished follow changes.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
                ],
              ),
            );
            if (shouldClose == true && context.mounted) Navigator.of(context).pop();
          } else {
            Navigator.of(context).pop();
          }
        },
        child: const Text('Close'),
      ),
    ];
  }

  Widget _buildTabToggle({
    required List<String> labels,
    required int? selected,
    required void Function(int) onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 88),
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected == i ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: selected == i ? Colors.blue : Colors.grey),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: selected == i ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildKeysSection(TrustGraph tg, Labeler labeler, List<String> delegates) {
    return ExpansionTile(
      controller: _keysController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _keysController),
      trailing: const SizedBox.shrink(),
      title: Row(
        children: [
          const Expanded(
            child: Text('Keys', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          _buildTabToggle(
            labels: const ['identity', 'delegate'],
            selected: _keysTab,
            onTap: (i) {
              setState(() => _keysTab = i);
              _keysController.expand();
            },
          ),
        ],
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        if ((_keysTab ?? 0) == 0) ...[
          ...tg.getEquivalenceGroup(widget.identity).map((IdentityKey equivKey) {
            final equivIdentityToken = equivKey.value;
            final bool isCanonical = equivKey == widget.identity;
            final String equivIdentityLabel = labeler.getLabel(equivIdentityToken);
            final status = isCanonical ? KeyStatus.active : KeyStatus.revoked;

            return Builder(builder: (context) {
              TapDownDetails? tapDetails;
              return Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTapDown: (details) => tapDetails = details,
                  onTap: () {
                    final FedKey? hk = FedKey.find(IdentityKey(equivIdentityToken));
                    KeyInfoView.show(context, equivIdentityToken, FirebaseConfig.resolveUrl((hk?.endpoint['url'] as String?) ?? kNativeUrl),
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
                        KeyIcon(type: KeyType.identity, status: status, presence: KeyPresence.known),
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
        ] else ...[
          if (delegates.isEmpty)
            const Text('None', style: TextStyle(fontSize: 12, color: Colors.grey))
          else ...[
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
                    onTap: () {
                      final domain = labeler.delegateResolver
                          ?.getDomainForDelegate(DelegateKey(d));
                      final isHablo = domain == 'hablotengo.com';
                      final baseUrl = isHablo
                          ? FirebaseConfig.resolveUrl('https://export.hablotengo.com')
                          : FirebaseConfig.contentUrl;
                      final specOverride =
                          isHablo ? '${d}_${widget.identity.value}' : null;
                      KeyInfoView.show(context, d, baseUrl,
                          details: tapDetails,
                          source: widget.controller.contentSource,
                          labeler: labeler,
                          specOverride: specOverride,
                          constraints: const BoxConstraints(maxWidth: 600));
                    },
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
                                  decorationColor: Colors.blue)),
                        ],
                      ),
                    ),
                  ),
                );
              });
            }),
          ],
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildFollowContextsSection() {
    if (signInState.hasIdentity && signInState.identity.value == widget.identity.value) {
      return const Text("This is you.", style: TextStyle(fontStyle: FontStyle.italic));
    }

    final label = model.labeler.getLabel(widget.identity.value);

    return ExpansionTile(
      controller: _followController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _followController),
      trailing: const SizedBox.shrink(),
      title: Text('How I follow/block $label',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: true,
      children: [
        _buildAddContextRow(),
        const SizedBox(height: 8),
        if (_pendingContexts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text('Not following in any context.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
          ),
        ..._pendingContexts.entries.map((e) => _buildContextRow(e.key, e.value)),
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

    return Autocomplete<String>(
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
          _pendingContexts[selection] = 0;
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
              hintText: 'Add context (e.g. nerd)',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (String value) async {
              if (value.isNotEmpty) {
                if ((await checkSignedIn(context, trustGraph: model.trustGraph)) != true) return;
                setState(() {
                  _pendingContexts[value] = 0;
                  controller.clear();
                });
              }
            },
          ),
        );
      },
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
      );

      await widget.controller.push(json, signer, context: context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow preferences updated.')),
        );

        setState(() {
          _pendingContexts.removeWhere((key, value) => value == 0);
          _originalContexts = Map.of(_pendingContexts);
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

  Widget _buildFollowsVouchesSection(IdentityKey identity, FeedModel model, String fcontext) {
    final String sectionTitle = fcontext == kFollowContextIdentity
        ? 'Vouches'
        : 'Follows ($fcontext)';

    return ExpansionTile(
      controller: _followsVouchesController,
      onExpansionChanged: (val) => _onExpansionChanged(val, _followsVouchesController),
      trailing: const SizedBox.shrink(),
      title: Row(
        children: [
          Expanded(
            child: Text(sectionTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          _buildTabToggle(
            labels: const ['incoming', 'outgoing'],
            selected: _followsTab,
            onTap: (i) {
              setState(() => _followsTab = i);
              _followsVouchesController.expand();
            },
          ),
        ],
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      initiallyExpanded: false,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: (_followsTab ?? 0) == 0
              ? _buildIncomingContent(identity, model, fcontext)
              : _buildOutgoingContent(identity, model, fcontext),
        ),
      ],
    );
  }

  Widget _buildIncomingContent(IdentityKey identity, FeedModel model, String fcontext) {
    if (fcontext == kFollowContextIdentity) {
      final List<TrustStatement> statements = model.trustGraph.edges.values
          .expand((l) => l)
          .where((s) => s.verb == TrustVerb.trust)
          .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statements.isEmpty) const Text('None'),
          ...statements.map((s) => _buildStatementTile(s, model)),
        ],
      );
    } else if (fcontext == kFollowContextNerdster) {
      final fn = model.followNetwork;
      final tg = model.trustGraph;

      final List<ContentStatement> explicitStatements = fn.edges.values
          .expand((l) => l)
          .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
          .where((s) => s.contexts?.containsKey(kFollowContextNerdster) == true)
          .toList();

      final explicitIssuers =
          explicitStatements.map((s) => _resolveDelegate(DelegateKey(s.iKey.value), model)).toSet();

      final List<TrustStatement> implicitStatements = tg.edges.values
          .expand((l) => l)
          .where((s) => s.verb == TrustVerb.trust)
          .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
          .where((s) {
        final issuer = _resolveDelegate(DelegateKey(s.iKey.value), model);
        return !explicitIssuers.contains(issuer);
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Includes explicit follows AND implicit follows derived from Trust (unless overridden).',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          const Text('Explicit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          if (explicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
          ...explicitStatements.map((s) => _buildStatementTile(s, model, fcontext: kFollowContextNerdster)),
          const SizedBox(height: 8),
          const Text('Implicit (Trust):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          if (implicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
          ...implicitStatements.map((s) => _buildStatementTile(s, model)),
        ],
      );
    } else {
      final List<ContentStatement> statements = model.followNetwork.edges.values
          .expand((l) => l)
          .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
          .where((s) => s.contexts?.containsKey(fcontext) == true)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statements.isEmpty) const Text('None'),
          ...statements.map((s) => _buildStatementTile(s, model, fcontext: fcontext)),
        ],
      );
    }
  }

  Widget _buildOutgoingContent(IdentityKey identity, FeedModel model, String fcontext) {
    if (fcontext == kFollowContextIdentity) {
      final List<TrustStatement> statements =
          (model.trustGraph.edges[identity] ?? []).where((s) => s.verb == TrustVerb.trust).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statements.isEmpty) const Text('None'),
          ...statements.map((s) => _buildStatementTile(s, model, isOutgoing: true)),
        ],
      );
    } else if (fcontext == kFollowContextNerdster) {
      final fn = model.followNetwork;
      final tg = model.trustGraph;

      final List<ContentStatement> explicitStatements = fn.edges.values
          .expand((l) => l)
          .where((s) => _resolveIdentity(IdentityKey(s.iKey.value), model) == identity)
          .where((s) => s.contexts?.containsKey(kFollowContextNerdster) == true)
          .toList();

      final explicitSubjects =
          explicitStatements.map((s) => _resolveIdentity(IdentityKey(s.subjectToken), model)).toSet();

      final List<TrustStatement> implicitStatements =
          (tg.edges[identity] ?? []).where((s) => s.verb == TrustVerb.trust).where((s) {
        final subject = _resolveIdentity(IdentityKey(s.subjectToken), model);
        return !explicitSubjects.contains(subject);
      }).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Includes explicit follows AND implicit follows derived from Trust.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          const Text('Explicit:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          if (explicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
          ...explicitStatements.map((s) => _buildStatementTile(s, model, fcontext: kFollowContextNerdster, isOutgoing: true)),
          const SizedBox(height: 8),
          const Text('Implicit (Trust):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          if (implicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
          ...implicitStatements.map((s) => _buildStatementTile(s, model, isOutgoing: true)),
        ],
      );
    } else {
      final List<ContentStatement> statements = model.followNetwork.edges.values
          .expand((l) => l)
          .where((s) => _resolveIdentity(IdentityKey(s.iKey.value), model) == identity)
          .where((s) => s.contexts?.containsKey(fcontext) == true)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statements.isEmpty) const Text('None'),
          ...statements.map((s) => _buildStatementTile(s, model, fcontext: fcontext, isOutgoing: true)),
        ],
      );
    }
  }

  Widget _buildStatementTile(dynamic s, FeedModel model,
      {String? fcontext, bool isOutgoing = false}) {
    final labeler = model.labeler;

    IdentityKey relevantKey;
    if (isOutgoing) {
      if (s is TrustStatement) {
        relevantKey = IdentityKey(s.subjectToken);
      } else if (s is ContentStatement) {
        relevantKey = IdentityKey(s.subjectToken);
      } else {
        relevantKey = IdentityKey('?');
      }
    } else {
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
       final Uri uri = Uri.parse('https://one-of-us.net/$verb#$fragment');
       content = ListTile(
         leading: const Icon(Icons.link),
         title: const Text('https://one-of-us.net/...'),
         subtitle: const Text('Use your identity app'),
         onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
       );
    } else if (method == SignInMethod.keymeid) {
       final Uri uri = Uri.parse('keymeid://$verb#$fragment');
       content = ListTile(
         leading: const Icon(Icons.link),
         title: const Text('keymeid://...'),
         subtitle: const Text('Use your identity app'),
         onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
       );
    } else {
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
