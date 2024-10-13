import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_bar.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/content_tile.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/content/content_types.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/content/dialogs/establish_subject_dialog.dart';
import 'package:nerdster/content/dialogs/rate_dialog.dart';
import 'package:nerdster/content/dialogs/relate_dialog.dart';
import 'package:nerdster/follow/most_contexts.dart';
import 'package:nerdster/content/props.dart';
import 'package:nerdster/equivalence/equate_statement.dart';
import 'package:nerdster/equivalence/equivalence_bridge.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

/// In preparation for NerdsterFollow:
/// - code sync with phone app
///
/// - cleaner, tighter, better...
///
/// - Teach TrustBridge that replace is different from block / revoke.
///   This may make trust1 be the algorithm for NerdsterFollow.
///
/// - Move functionality to smaller, isolated Comps
///   - ContentBase
///     - Censored: likely (a.k.a. uncensored)
///     - equivalent / related subjects? - unlikely
///   - NetNode: (is this a Comps?)
///   - NetTreeNode: (is this a Comps?)
/// - Find/fix bugs:
///   - censor and/or dis combined with equivalent and/or related
/// - Stop using statement.iToken and instead rely on token2statements,
///   - FollowNet().token2statements
///   - Censored().token2statements
///   - NerdsterFollow().token2statements
///   Have everything in terms of Oneofus canonical, that is.

class ContentBase with Comp, ChangeNotifier {
  static final OouVerifier verifier = OouVerifier();
  static final ContentBase _singleton = ContentBase._internal();
  factory ContentBase() => _singleton;

  final EquivalenceBridge _equivalence = EquivalenceBridge(_ContentEquateParser(), null);
  final EquivalenceBridge _related = EquivalenceBridge(_ContentRelateParser(), null);
  final Set<String> _censored = <String>{};
  final Map<String, List<ContentStatement>> _subject2statements =
      <String, List<ContentStatement>>{};
  List<ContentTreeNode>? _roots;
  final Map<ContentTreeNode, List<ContentTreeNode>> _node2children =
      <ContentTreeNode, List<ContentTreeNode>>{};

  // Bar filters, sort, ...
  MostContexts mostTags = MostContexts();
  Sort _sort = Sort.recentActivity;
  ContentType _type = ContentType.all;
  Timeframe _timeframe = Timeframe.all;
  bool _censor = true;

  Future<Jsonish> insert(Json json) async {
    String iToken = getToken(json['I']);
    assert(signInState.signedInDelegate == iToken);
    Fetcher fetcher = Fetcher(iToken, kNerdsterDomain);
    Jsonish statement = await fetcher.push(json, signInState.signer!);
    listen();
    return statement;
  }

  Iterable<ContentStatement>? getSubjectStatements(String subject) {
    return _subject2statements[subject];
    // Skipping censored statements not necessary here, already I think.
  }

  Iterable<ContentTreeNode>? getChildren(ContentTreeNode node) {
    return _node2children[node];
  }

  @override
  Future<void> process() async {
    assert(supportersReady);
    _equivalence.clear();
    _related.clear();
    _censored.clear();
    _subject2statements.clear();
    _node2children.clear();
    _roots = null;
    mostTags.clear();

    List<ContentStatement> statements = <ContentStatement>[];
    for (String oneofus in followNet.oneofus2delegates.keys) {
      statements
          .addAll(followNet.getStatements(oneofus).where((s) => s.verb != ContentVerb.follow));
    }

    /// Censoring: who gets to do what? (Note: this used to be called delete)
    /// - (I can always censor my own statements. GONE: I can clear my own statements.)
    /// - I can always censor statements or subjects for myself.
    /// - "censor" disabled: no one gets to censor subjects or statements for you
    /// - "censor" enabled: your network censor subjects or statements for you
    ///
    /// What about statements about statements ... about censored subjects?
    /// - (GONE: I think that these just have nowhere to be. Censor everything about it including
    ///   all statements about it as well statements about those statements, etc..)
    ///
    /// What about the censor statement itself?
    /// - If a subject (or a statement) is successfully censored, then all statements about it (including its censorship)
    ///   should be hidden (and there'd be nowhere to display it in the tree anyway).
    /// In case I censor a subject and later change my mind... Well, I'd need to find that statement first (re-center, uncheck 'censor')
    /// - If a subject (or statement) is un-successfully censored, then the statement of its censorship should be shown.
    ///
    /// What if I try to censor a subject (for others) but am not allowed (by their censor setting), do I still get
    /// to censor everything I said about it?
    /// (Gone: Yes. (discussion omitted. Question below is related.))
    /// No: I can clear my own statements.
    ///
    /// What about statements left hanging with no subject to be about?
    /// I say X. You say Y about my X. I censor my X. Your Y has nowhere to be. Yep.
    ///
    /// Hmm..: Censoring censorship (Deleting a deletion..)
    /// deleter1 issues deletion1 to delete subject
    /// deleter2 issues deletion2 to delete deletion1
    /// Cases:
    /// I am deleter2
    ///   censorship enabled :   deletion2 respected, not visible; deletion1 ignored, not visible (because it's deleted)
    ///   censorship disabled:   deletion2 respected, not visible; deletion1 ignored, not visible (because it's deleted)
    /// I am deleter1
    ///   censorship enabled: THE CRUX (of the biscuit)!
    ///     I just deleted subject1; I don't want to see it! I have censorship enabled, but I don't want my censorship censored.
    ///                          deletion1 respected, not visible; deletion2 ignored, not visible (because deletion1 is not visible).
    ///   censorship disabled:   deletion1 respected, not visible; deletion2 ignored, not visible (because deletion1 is not visible)
    /// I am someone unrelated:
    ///   deleter1 trumps deleter2:
    ///     censorship enabled:  deletion1 respected, not visible; deletion2 ignored, not visible (because deletion1 is not visible).
    ///     censorship disabled: deletion2 ignored, visible; deletion2 ignored, visible
    ///   deleter2 trumps deleter1:
    ///     censorship enabled:  deletion2 respected, not visible; deletion1 ignored, not visible (because it's deleted)
    ///     censorship disabled: deletion1 ignored, visible; deletion2 ignored, visible
    /// It seems that a simple loop through to delete deleted deletions address everything.
    ///
    /// Hmm..: Deleting a deletion of a deletion.. or worse..
    /// Players
    ///   deleter1 issues deletion1 to delete subject1
    ///   deleter2 issues deletion2 to delete deletion1
    ///   deleter3 issues deletion3 to delete deletion2
    /// I don't see a problem.
    ///
    /// So:
    /// Check each statement: If it, its subject, that thing's subject, etc... has been censored, then:
    /// - check our censor settings and the censorer
    ///   If censorship is allowed then:
    ///     don't include it (censor it)
    ///   If not allowed then:
    ///     do include it as usual (and also display the censorship statement about it)
    /// - Hide things whose only children are censor/delete statements.

    if (_censor) {
      /// delete deletions correctly (more trusted can delete less trusted)
      for (final ContentStatement statement
          in statements.where((s) => s.verb == ContentVerb.censor)) {
        if (_censored.contains(statement.token)) {
          continue;
        }
        _censored.add(statement.subjectToken);
      }

      // Filter censored statements and statements about censored subjects
      statements.removeWhere((s) => _censored.contains(s.token));
      statements.removeWhere((s) => _censored.contains(s.subjectToken));
      statements.removeWhere((s) => b(s.other) && _censored.contains(getToken(s.other)));
    }

    // equivalent..
    for (ContentStatement statement in statements) {
      _equivalence.process(statement);
    }
    _equivalence.make();

    // related..
    for (ContentStatement statement in statements) {
      _related.process(statement);
    }
    _related.make();

    // _subject2statements
    for (ContentStatement statement in statements) {
      // TODO: CONSIDER: filters only for 'rate', not equate, relate, censor
      if (_filterByTType(statement) || _filterByTimeframe(statement)) {
        continue;
      }
      Set<String> subjectTokens = _getSubjectTokens(statement);
      for (String subjectToken in subjectTokens) {
        _subject2statements.putIfAbsent(subjectToken, () => <ContentStatement>[]).add(statement);
        // Also use canonical subject
        String canonicalSubjectToken = _equivalence.getCanonical(subjectToken);
        if (!subjectTokens.contains(canonicalSubjectToken)) {
          _subject2statements
              .putIfAbsent(canonicalSubjectToken, () => <ContentStatement>[])
              .add(statement);
        }
      }
    }

    ReactIconStateClearHelper.clear();

    BarRefresh.elapsed(runtimeType.toString());
  }

  /// Censor if any of these hold:
  /// - (GONE: I censored this. I could just clear it.)
  /// - I have censorship enabled and someone in my network censored this
  /// - (Gone: author of this censored it himself.. Gone because author can clear his own stuff anyway.)
  bool _isCensored(String subject) => _censor && _censored.contains(subject);

  // CODE: 'get roots'
  Iterable<ContentTreeNode> getRoots() {
    if (b(_roots)) {
      return _roots!;
    }
    _roots = <ContentTreeNode>[];
    for (String subjectToken in _subject2statements.keys) {
      final Jsonish subject = Jsonish.find(subjectToken)!;

      // skip statements
      if (subject.json.containsKey('statement')) {
        continue;
      }

      // skip non-canonicals
      if (_equivalence.getCanonical(subjectToken) != subjectToken) {
        continue;
      }

      // Skip dismissed
      if (_subject2statements[subjectToken]!.any(
          (statement) => b(statement.dismiss) && _getOneofusI(statement.iToken) == signInState.center)) {
        continue;
      }

      ContentTreeNode subjectNode = ContentTreeNode([], subject);

      _roots!.add(subjectNode);
    }

    // Looks like we build all children. Note that unlike NerdTree, this shouldn't be a deep tree.
    // We currently use the children to compute some of the props, and so might actually want them all.
    for (ContentTreeNode node in _roots!) {
      _addChildren(node);
    }

    _roots!.sort((a, b) {
      PropType sort = _sort.propType;
      return b
          .computeProps([sort])[_sort.propType]!
          .getComparable()!
          .compareTo(a.computeProps([_sort.propType])[_sort.propType]!.getComparable());
    });

    return _roots!;
  }

  void _addChildren(ContentTreeNode node) {
    assert(!_node2children.containsKey(node));
    final List<String> path = List.from(node.path)..add(node.subject.token);
    _node2children[node] = <ContentTreeNode>[];

    // Don't show subject node children if related or equivalent (do show statements, below..)
    if (!node.equivalent && !node.related) {
      // related (not canonical) subjects; omit the canonical (it'd be a child of itself).
      Iterable<String> relatedTokens = _related.getEquivalents(node.subject.token);
      relatedTokens = relatedTokens.where((token) => token != node.subject.token);
      for (String relatedToken in relatedTokens) {
        assert(!_isCensored(relatedToken));
        // Skip dismissed. TODO: Test
        if (_subject2statements[relatedToken]!.any((statement) =>
            b(statement.dismiss) && _getOneofusI(statement.iToken) == signInState.center)) {
          continue;
        }

        Jsonish relatedSubject = Jsonish.find(relatedToken)!;
        ContentTreeNode relatedNode = ContentTreeNode(path, relatedSubject, related: true);
        if (!node.path.contains(relatedNode.subject.token)) {
          _node2children[node]!.add(relatedNode);
          _addChildren(relatedNode);
        }
      }

      // same but for equivalents
      Iterable<String> equivalentTokens = _equivalence.getEquivalents(node.subject.token);
      equivalentTokens = equivalentTokens.where((token) => token != node.subject.token);
      for (String equivalentToken in equivalentTokens) {
        assert(!_isCensored(equivalentToken));
        Jsonish equivalentSubject = Jsonish.find(equivalentToken)!;
        ContentTreeNode equivalentNode = ContentTreeNode(path, equivalentSubject, equivalent: true);
        if (!node.path.contains(equivalentNode.subject.token)) {
          _node2children[node]!.add(equivalentNode);
          _addChildren(equivalentNode);
        }
      }
    }

    for (ContentStatement statement in _subject2statements[node.subject.token] ?? []) {
      assert(!_isCensored(statement.token));
      // Skip dismissed. TODO: Test
      if (b(_subject2statements[statement.token]) &&
          _subject2statements[statement.token]!.any((statement) =>
              b(statement.dismiss) && _getOneofusI(statement.iToken) == signInState.center)) {
        continue;
      }

      ContentTreeNode statementNode = ContentTreeNode(path, Jsonish(statement.json));
      _node2children[node]!.add(statementNode);
      // Rare (even demented) case: statement is related to subject.
      // Why am I even working on this? Because someone might do it, and I don't want to crash (stack overflow)
      // The less demented case would be to relate (or equate) something in the tree to something else in the tree.
      // The code now does show 2 child statements in case a statement is about the subject and is also related to it;
      // but they're different SubjectTreeNode instances because one has related=true, and the other doesn't.
      // It's fine; I'm leaving it.
      if (!_node2children.containsKey(statementNode)) {
        _addChildren(statementNode);
      }
    }
  }

  Sort get sort => _sort;
  set sort(Sort sort) {
    _sort = sort;
    listen();
  }

  ContentType get type => _type;
  set type(ContentType type) {
    _type = type;
    listen();
  }

  Timeframe get timeframe => _timeframe;
  set timeframe(Timeframe timeframe) {
    _timeframe = timeframe;
    listen();
  }

  bool get censor => _censor;
  set censor(bool censor) {
    _censor = censor;
    listen();
  }

  Iterable<String> getMostTags() => mostTags.most();

  // returns if we should filter this one out
  bool _filterByTimeframe(Statement statement) {
    return _timeframe != Timeframe.all &&
        DateTime.now().subtract(Duration(days: _timeframe.days!)).isAfter(statement.time);
  }

  // returns if we should filter this one out
  bool _filterByTType(ContentStatement statement) {
    return _type != ContentType.all && !findContentTypes(statement.json).contains(_type);
  }

  /// Delete/Censor statements are about subjects, but they don't contain the subjects (as that'd
  /// defeat the purpose of censoring a subject). Instead they contain a subject token.
  /// This is a convenience method to get the subject token(s) of a statement.
  static Set<String> _getSubjectTokens(ContentStatement statement) {
    Set<String> out = <String>{};
    out.add(statement.subjectToken);
    if (b(statement.other)) {
      out.add(getToken(statement.other));
    }
    return out;
  }

  // Used to find ContentTypes for filtering statements.
  // Sometimes we statements about a statements about about ... a
  // subject or even subjects (relate, for example).
  static Set<ContentType> findContentTypes(Json json) {
    if (json.containsKey('statement')) {
      ContentStatement statement = ContentStatement(Jsonish(json));
      dynamic subject = statement.subject;
      dynamic otherSubject = statement.other;
      if (b(subject) && b(otherSubject)) {
        return findContentTypes(subject).union(findContentTypes(otherSubject));
      } else if (b(subject)) {
        return findContentTypes(subject);
      } else {
        return {};
      }
    } else if (json.containsKey('contentType')) {
      ContentType contentType = ContentType.values.byName(json['contentType']);
      return {contentType};
    } else {
      return {};
    }
  }

  dynamic dump() {
    List roots = [];
    for (ContentTreeNode subjectNode in getRoots()) {
      Map<dynamic, dynamic> map = {};
      roots.add(map);
      map['subject'] = subjectNode.subject.json;
      // NOTE: These props can be different from the UI props (rating here, recommend there).
      // This makes it easy to pass the tests that were scripted and recorded before the change,
      // but it's not awesome.
      Map<PropType, Prop> props = subjectNode.computeProps(
          [PropType.recommend, PropType.numComments, PropType.recentActivity]);
      Map<dynamic, dynamic> propsMap = {};
      for (var entry in props.entries) {
        propsMap[entry.key.label] = entry.value.getValue();
      }
      map['props'] = propsMap.map((k, v) => MapEntry(k, (v is DateTime) ? formatUiDatetime(v) : v));
      List children = [];
      map['children'] = children;
      for (ContentTreeNode child in subjectNode.getChildren()) {
        Map<dynamic, dynamic> childMap = {};
        children.add(childMap);
        childMap['subject'] = child.subject.json;
      }
    }
    return roots;
  }

  bool isRejected(String token) {
    return _equivalence.isRejected(token) || _related.isRejected(token);
  }

  // This class gets the actual statements from FollowNet (soon to be NerdsterFollowNet),
  // and they arrive grouped under the canonical, oneofus author.
  // But this class then just jams them into _statements, not _oneofus2statements, and so we
  // immediately lose the logical author.
  // We use this helper, but a rewrite could keep the author we want instead.
  String _getOneofusI(String delegateToken) => followNet.delegate2oneofus[delegateToken]!;

  Set<ContentStatement> findMyStatements(String subjectToken) {
    Set<ContentStatement> out = <ContentStatement>{};
    List<ContentStatement>? statements = _subject2statements[subjectToken];
    for (ContentStatement statement in statements ?? []) {
      if ((_getOneofusI(statement.iToken) == signInState.center) &&
          (subjectToken == statement.subjectToken ||
              (b(statement.other) && subjectToken == getToken(statement.other)))) {
        out.add(statement);
      }
    }
    return out;
  }

  // CODE: Implement this using statement.distictSignature.
  ContentStatement? _findMyStatement1(String subject) {
    List<ContentStatement>? statements = _subject2statements[subject];
    for (ContentStatement statement in statements ?? []) {
      if (_getOneofusI(statement.iToken) == signInState.center &&
          statement.subjectToken == subject &&
          !b(statement.other)) {
        return statement;
      }
    }
    return null;
  }

  // CODE: Implement this using statement.distictSignature.
  ContentStatement? _findMyStatement2(String subject, String other) {
    List<ContentStatement>? statements = _subject2statements[subject];
    for (ContentStatement statement in statements ?? []) {
      if (_getOneofusI(statement.iToken) == signInState.center && b(statement.other)) {
        String otherToken = getToken(statement.other);
        if ((statement.subjectToken == subject && otherToken == other) ||
            (statement.subjectToken == other && otherToken == subject)) {
          return statement;
        }
      }
    }
    return null;
  }

  ContentBase._internal() {
    _initWindowQueryParams();

    // supporters
    addSupporter(followNet);
    followNet.addListener(listen);
    addSupporter(oneofusEquiv);
    oneofusEquiv.addListener(listen);
  }

  void listen() {
    setDirty();
    notifyListeners();
  }

  @override
  void dispose() {
    followNet.removeListener(listen);
    oneofusEquiv.removeListener(listen);
    super.dispose();
  }

  void _initWindowQueryParams() {
    Map<String, String> params = Uri.base.queryParameters;

    String? sortParam = params['sort'];
    if (b(sortParam)) {
      try {
        sort = Sort.values.byName(sortParam!);
        print('sort=$sort');
      } catch (e) {
        print(e);
      }
    }

    String? typeParam = params['type'];
    if (b(typeParam)) {
      try {
        type = ContentType.values.byName(typeParam!);
        print('type=$type');
      } catch (e) {
        print(e);
      }
    }

    String? timeframeParam = params['timeframe'];
    if (b(timeframeParam)) {
      try {
        timeframe = Timeframe.values.byName(timeframeParam!);
        print('timeframe=$timeframe');
      } catch (e) {
        print(e);
      }
    }

    String? censorParam = params['censor'];
    if (b(censorParam)) {
      try {
        censor = bool.parse(censorParam!);
        print('censor=$censor');
      } catch (e) {
        print(e);
      }
    }
  }
}

class _ContentEquateParser implements EquivalenceBridgeParser {
  final Set<ContentVerb> _equateVerbs = {ContentVerb.equate, ContentVerb.dontEquate};

  @override
  EquateStatement? parse(Statement s) {
    ContentStatement statement = s as ContentStatement;
    ContentVerb verb = statement.verb;
    if (_equateVerbs.contains(verb)) {
      bool dont = (verb == ContentVerb.dontEquate);
      String canonical = statement.subjectToken;
      String equivalent = getToken(statement.other);
      return EquateStatement(canonical, equivalent, dont: dont);
    }
    return null;
  }
}

class _ContentRelateParser implements EquivalenceBridgeParser {
  final Set<ContentVerb> _relateVerbs = {
    ContentVerb.relate,
    ContentVerb.dontRelate,
  };

  @override
  EquateStatement? parse(Statement s) {
    ContentStatement statement = s as ContentStatement;
    ContentVerb verb = statement.verb;
    if (_relateVerbs.contains(verb)) {
      bool dont = (verb == ContentVerb.dontRelate);
      String canonical = statement.subjectToken;
      String equivalent = getToken(statement.other);
      return EquateStatement(canonical, equivalent, dont: dont);
    }
    return null;
  }
}

Future<Jsonish?> submit(BuildContext context) async {
  if (await checkSignedIn(context) != true) {
    return null;
  }
  Jsonish? subject = await establishSubjectDialog(context);
  if (subject != null) {
    Jsonish? statement = await rate(subject, context);
    return statement;
  }
  return null;
}

// CONSIDER: Pass a constructed Jsonish? statement in and let the dialog set certain fields.
Future<Jsonish?> rate(Jsonish subject, BuildContext context) async {
  if (await checkSignedIn(context) != true) {
    return null;
  }
  ContentStatement? priorStatement = contentBase._findMyStatement1(subject.token);
  Json? json = await rateDialog(context, subject, priorStatement);
  if (json != null) {
    Jsonish statement = await contentBase.insert(json);
    return statement;
  }
  return null;
}

Future<Jsonish?> relate(Jsonish subject, Jsonish otherSubject, BuildContext context) async {
  if (await checkSignedIn(context) != true) {
    return null;
  }
  ContentStatement? priorStatement = contentBase._findMyStatement2(subject.token, otherSubject.token);
  Json? json = await relateDialog(context, subject.json, otherSubject.json, priorStatement);
  if (json != null) {
    Jsonish statement = await contentBase.insert(json);
    return statement;
  }
  return null;
}
