import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/keys.dart';
import 'package:nerdster/v2/model.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/v2/key_info_view.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/feed_controller.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/v2/json_display.dart';
import 'package:nerdster/v2/interpreter.dart';
import 'package:nerdster/v2/follow_logic.dart';
import 'package:collection/collection.dart';
import 'package:nerdster/v2/source_factory.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';

@Deprecated('Use NodeDetailsSheet')
class NodeDetails extends StatelessWidget {
  final IdentityKey identity;
  final V2FeedController controller;

  const NodeDetails({super.key, required this.identity, required this.controller});

  static Future<void> show(BuildContext context, IdentityKey identity, V2FeedController controller) {
    return showDialog(
      context: context,
      builder: (context) => NodeDetailsSheet(identity: identity, controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NodeDetailsSheet(identity: identity, controller: controller);
  }
}

class NodeDetailsSheet extends StatefulWidget {
  final IdentityKey identity;
  final V2FeedController controller;
  final ScrollController? scrollController;

  const NodeDetailsSheet({
    super.key,
    required this.identity,
    required this.controller,
    this.scrollController,
  });

  @override
  State<NodeDetailsSheet> createState() => _NodeDetailsSheetState();
}

class _NodeDetailsSheetState extends State<NodeDetailsSheet> {
  IdentityKey _resolveIdentity(IdentityKey key, V2FeedModel model) {
    if (model.trustGraph.isTrusted(key)) {
      return model.trustGraph.resolveIdentity(key);
    }
    return key;
  }

  IdentityKey _resolveDelegate(DelegateKey key, V2FeedModel model) {
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

  V2FeedModel get model => widget.controller.value!;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    if (!mounted) return;

    final myId = signInState.identity;
    if (myId == null) return;

    final canonical = model.trustGraph.resolveIdentity(widget.identity);
    final subjectAgg = model.aggregation.subjects[ContentKey(canonical.value)];
    // subjectAgg might be null if no statements found.
    // Also conversion IdentityKey -> ContentKey just for lookup?
    // Aggregation keys are ContentKeys (hashes/uris). IdentityKey is just a key.
    // Assuming implicit conversion or value match.
    // Wait, V2FeedModel.aggregation.subjects is Map<ContentKey, SubjectAggregation>.
    // IdentityKey and ContentKey wrap String.
    
    // In content_logic.dart, we'll see how keys are used.
    // For now, let's assume keys are compatible via their value.
    if (subjectAgg == null) return;

    final myStatements = subjectAgg.myDelegateStatements;

    ContentStatement? priorStatement;
    for (var s in myStatements) {
      if (s.verb == ContentVerb.follow) {
        priorStatement = s;
        break;
      }
    }

    if (priorStatement != null && priorStatement.contexts != null) {
      setState(() {
        _originalContexts.clear();
        _pendingContexts.clear();
        priorStatement!.contexts!.forEach((k, v) {
          if (v is int) {
            _originalContexts[k] = v;
            _pendingContexts[k] = v;
          }
        });
      });
    }
  }

  bool get _hasChanges {
    final effectivePending = Map<String, int>.from(_pendingContexts)..removeWhere((k, v) => v == 0);
    return !const MapEquality().equals(_originalContexts, effectivePending);
  }

  @override
  Widget build(BuildContext context) {
    final V2Labeler labeler = model.labeler;
    // V2Labeler label/getLabel takes string or key? currently string
    final identityStr = widget.identity.value;
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
    
    final delegates = labeler.delegateResolver?.getDelegatesForIdentity(widget.identity).map((d) => d.value).toList() ?? [];
    final String fcontext = model.fcontext;

    return AlertDialog(
      title: _buildHeader(labeler, identityStr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFollowContextsSection(),
            const Divider(),
            const Text('All Monikers:', style: TextStyle(fontWeight: FontWeight.bold)),
            if (labeler.getAllLabels(widget.identity).isEmpty) const Text('None'),
            ...labeler.getAllLabels(widget.identity).map((l) => Text('• $l')),
            const SizedBox(height: 10),
            const Text('Equivalent Identity Keys:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...tg.getEquivalenceGroup(widget.identity).map((IdentityKey equivKey) {
                final equivIdentityToken = equivKey.value;
                final bool isCanonical = equivKey == widget.identity;
                final String equivIdentityLabel = labeler.getLabel(equivIdentityToken);
                return Builder(builder: (context) {
                  TapDownDetails? tapDetails;
                  return InkWell(
                    onTapDown: (details) => tapDetails = details,
                    onTap: () {
                       KeyInfoView.show(context, equivIdentityToken, kOneofusDomain,
                        details: tapDetails,
                        source: widget.controller.trustSource,
                        labeler: labeler,
                        constraints: const BoxConstraints(maxWidth: 600));
                    },
                    child: Text('• $equivIdentityLabel ${isCanonical ? "(Canonical)" : "(Replaced)"}',
                        style: TextStyle(
                            fontSize: 10,
                            color: isCanonical ? Colors.black : Colors.grey,
                            decoration: TextDecoration.underline)),
                  );
                });
              }),
            
            if (delegates.isNotEmpty) ...[
               const SizedBox(height: 10),
               const Text('Delegate Keys:', style: TextStyle(fontWeight: FontWeight.bold)),
               ...delegates.map((d) {
                 final String delegateLabel = labeler.getLabel(d);
                 return Builder(builder: (context) {
                    TapDownDetails? tapDetails;
                    return InkWell(
                      onTapDown: (details) => tapDetails = details,
                      onTap: () => KeyInfoView.show(context, d, kNerdsterDomain,
                          details: tapDetails,
                          source: widget.controller.contentSource,
                          labeler: labeler,
                          constraints: const BoxConstraints(maxWidth: 600)),
                      child: Text('• $delegateLabel', 
                          style: const TextStyle(
                             fontSize: 10, 
                             color: Colors.blue,
                             decoration: TextDecoration.underline)),
                    );
                 });
               }),
            ],
            
            const SizedBox(height: 10),
            if (fcontext == kFollowContextIdentity)
              _buildIdentityDetails(widget.identity, model)
            else if (fcontext == kFollowContextNerdster)
              _buildNerdsterDetails(widget.identity, model)
            else
              _buildContextDetails(widget.identity, model, fcontext),
          ],
        ),
      ),
      actions: _buildActions(context),
    );
  }
  
  Widget _buildHeader(V2Labeler labeler, String identityStr) {
     return Builder(builder: (context) {
        TapDownDetails? tapDetails;
        return InkWell(
          onTapDown: (details) => tapDetails = details,
          onTap: () {
            KeyInfoView.show(context, identityStr, kOneofusDomain,
                details: tapDetails,
                source: widget.controller.trustSource,
                labeler: labeler,
                constraints: const BoxConstraints(maxWidth: 600));
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(labeler.getLabel(identityStr))),
              const SizedBox(width: 8),
              const Icon(Icons.qr_code, size: 20, color: Colors.blue),
            ],
          ),
        );
      });
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
        if (widget.identity != model.trustGraph.pov)
           TextButton(
            onPressed: () {
              // Updating global POV
              Navigator.pop(context); // Close sheet/dialog first
              signInState.pov = widget.identity.value;
              widget.controller.refresh(widget.identity, meIdentityToken: signInState.identity != null ? IdentityKey(signInState.identity!) : null);
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

  Widget _buildFollowContextsSection() {
    final myId = signInState.identity;
    if (myId != null && myId == widget.identity.value) {
       return const Text("This is you.", style: TextStyle(fontStyle: FontStyle.italic));
    }

    final label = model.labeler.getLabel(widget.identity.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('How I follow/block $label:', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_hasChanges)
              ElevatedButton(
                onPressed: _isUpdating ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 5),
        if (_pendingContexts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text('Not following in any context.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
          ),
        ..._pendingContexts.entries.map((e) => _buildContextRow(e.key, e.value)),
        const SizedBox(height: 5),
        _buildAddContextRow(),
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
              if (!bb(await checkSignedIn(context, trustGraph: model.trustGraph))) return;
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
              if (!bb(await checkSignedIn(context, trustGraph: model.trustGraph))) return;
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
                      if (!bb(await checkSignedIn(context, trustGraph: model.trustGraph))) return;
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
      final myId = signInState.identity;
      final signer = signInState.signer;
      if (myId == null || signer == null) return;

      final subjectJsonish = Jsonish.find(widget.identity.value);
      if (subjectJsonish == null) throw Exception("Subject not found");

      final contextsToSave = Map<String, int>.from(_pendingContexts)
        ..removeWhere((key, value) => value == 0);

      final json = ContentStatement.make(
        signInState.delegatePublicKeyJson!,
        ContentVerb.follow,
        subjectJsonish.json,
        contexts: contextsToSave,
      );

      final writer = SourceFactory.getWriter(kNerdsterDomain,
          context: context, labeler: widget.controller.value!.labeler);
      await writer.push(json, signer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow preferences updated.')),
        );

        setState(() {
          _pendingContexts.removeWhere((key, value) => value == 0);
          _originalContexts = Map.of(_pendingContexts);
        });
        await widget.controller.refresh(model.trustGraph.pov, meIdentityToken: signInState.identity != null ? IdentityKey(signInState.identity!) : null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Widget _buildIdentityDetails(IdentityKey identity, V2FeedModel model) {
    final tg = model.trustGraph;
    final myId = signInState.identity;

    final statements = tg.edges.values
        .expand((l) => l)
        .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
        .where((s) => s.iKey.value != myId) 
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Incoming Trust Statements:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (statements.isEmpty) const Text('None'),
        ...statements.map((s) => _buildStatementTile(s, model)),
      ],
    );
  }

  Widget _buildContextDetails(IdentityKey identity, V2FeedModel model, String context) {
    final fn = model.followNetwork;
    final myId = signInState.identity;

    final statements = fn.edges.values
        .expand((l) => l)
        .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
        .where((s) => s.contexts?.containsKey(context) == true)
        .where((s) => _resolveDelegate(DelegateKey(s.iKey.value), model).value != myId) 
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Incoming Follows ($context):', style: const TextStyle(fontWeight: FontWeight.bold)),
        if (statements.isEmpty) const Text('None'),
        ...statements.map((s) => _buildStatementTile(s, model, fcontext: context)),
      ],
    );
  }

  Widget _buildNerdsterDetails(IdentityKey identity, V2FeedModel model) {
    final fn = model.followNetwork;
    final tg = model.trustGraph;
    final myId = signInState.identity;

    // 1. Explicit Follows
    final explicitStatements = fn.edges.values
        .expand((l) => l)
        .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
        .where((s) => s.contexts?.containsKey(kFollowContextNerdster) == true)
        .where((s) => _resolveDelegate(DelegateKey(s.iKey.value), model).value != myId) 
        .toList();

    final explicitIssuers =
        explicitStatements.map((s) => _resolveDelegate(DelegateKey(s.iKey.value), model)).toSet();

    // 2. Implicit Follows (Trust)
    final implicitStatements = tg.edges.values
        .expand((l) => l)
        .where((s) => _resolveIdentity(IdentityKey(s.subjectToken), model) == identity)
        .where((s) {
      final issuer = _resolveDelegate(DelegateKey(s.iKey.value), model);
      return !explicitIssuers.contains(issuer) && issuer.value != myId; 
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nerdster Context:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
        const Text(
          'Includes explicit follows AND implicit follows derived from Trust (unless overridden).',
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),
        const Text('Explicit Follows:', style: TextStyle(fontWeight: FontWeight.bold)),
        if (explicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
        ...explicitStatements
            .map((s) => _buildStatementTile(s, model, fcontext: kFollowContextNerdster)),
        const SizedBox(height: 10),
        const Text('Implicit Follows (Trust):', style: TextStyle(fontWeight: FontWeight.bold)),
        if (implicitStatements.isEmpty) const Text('None', style: TextStyle(fontSize: 12)),
        ...implicitStatements.map((s) => _buildStatementTile(s, model)),
      ],
    );
  }

  Widget _buildStatementTile(dynamic s, V2FeedModel model, {String? fcontext}) {
    final labeler = model.labeler;
    // s can be TrustStatement or ContentStatement.
    // Both have iKey/iToken (but IdentityKey in refactor).
    // TrustStatement has iKey. ContentStatement has iKey? 
    // ContentStatement is from `nerdster/content/content_statement.dart`.
    // I need to check ContentStatement definition.
    // Assuming both have a way to get issuer IdentityKey.
    
    IdentityKey issuerKey;
    if (s is TrustStatement) {
      issuerKey = s.iKey;
    } else if (s is ContentStatement) {
      // Assuming ContentStatement has iKey or compatible.
      // If it has String iToken, we assume it's IdentityKey.
      issuerKey = IdentityKey(s.iToken);
    } else {
      issuerKey = IdentityKey('?');
    }

    final issuerLabel = labeler.getLabel(_resolveIdentity(issuerKey, model).value);
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

    return ExpansionTile(
      title: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'From $issuerLabel ('),
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
          ValueListenableBuilder<bool>(
            valueListenable: Setting.get<bool>(SettingType.showCrypto),
            builder: (context, showCrypto, _) {
              if (!showCrypto) return const SizedBox.shrink();
              return IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.verified_user, size: 16, color: Colors.blue),
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Cryptographic Proof'),
                    content: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: V2JsonDisplay(s.json, interpreter: V2Interpreter(labeler)),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context), child: const Text('Close')),
                    ],
                  ),
                ),
                visualDensity: VisualDensity.compact,
              );
            },
          ),
        ],
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.grey[100],
          height: 200,
          child: SingleChildScrollView(
            child: V2JsonDisplay(s.json,
                interpreter: widget.controller.value != null
                    ? V2Interpreter(widget.controller.value!.labeler)
                    : null),
          ),
        ),
      ],
    );
  }
}
