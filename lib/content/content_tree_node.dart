import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/content/props.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/singletons.dart';

import 'package:collection/collection.dart';

final listEq = ListEquality<String>();

/// Like [NerdTreeNode]:
/// - represents a node in the content tree. There may be more than one of these for a single logical subject.
/// - sometimes about a subject (book, movie, ...), sometimes about a statement.

class ContentTreeNode {
  final List<String> path;

  final Jsonish subject;

  final bool related;
  final bool equivalent;

  ContentTreeNode(this.path, this.subject, {this.related = false, this.equivalent = false});

  Iterable<ContentTreeNode> getChildren() {
    return contentBase.getChildren(this) ?? [];
  }

  // PERFORMANCE: We shouldn't compute props for each SubjectTreeNode but rather for each SubjectNode (doesn't exist (yet)).
  Map<PropType, Prop> computeProps(Iterable<PropType> propTypes) {
    final out = {
      for (final propType in propTypes) propType: cloners[propType]!.clone(),
    };
    _computePropsRecurse(out.values);
    return out;
  }

  void _computePropsRecurse(Iterable<Prop> props) {
    // our statements
    Iterable<ContentStatement>? statements = contentBase.getSubjectStatements(subject.token);
    for (ContentStatement statement in statements ?? []) {
      for (Prop prop in props) {
        prop.process(statement);
      }
    }

    // recurse for children
    for (ContentTreeNode child in getChildren()) {
      // Don't recurse for equivalent or related children.
      // BUG: I do want to recurse for some children; I just don't want to do it twice, and
      // this is better than doing it twice.
      if (child.equivalent || child.related) continue;

      Iterable<Prop> recurseProps = props.where((p) => p.recurse);
      child._computePropsRecurse(recurseProps);
    }
  }

  // I'm not sure I need this as instances of these things should all be distinct, never equal, never hash the same...
  @override
  bool operator ==(Object other) =>
      other is ContentTreeNode &&
      listEq.equals(path, other.path) &&
      subject.token == other.subject.token &&
      related == other.related &&
      equivalent == other.equivalent;

  @override
  int get hashCode => Object.hash(Object.hashAll(path), subject.token, related, equivalent);
}
