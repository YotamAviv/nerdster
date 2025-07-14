import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/util.dart';

/// compute aggregates
/// - count(comments)
/// - max(date) (recent activity)
/// - ..
///
/// Recent (7/19/24) distinct changes made this different, and I haven't looked closely at what this
/// used to do and why other than it's no longer required to use the user's last rating
/// (they're distinct now; there is only one).
///
/// for
/// - sort
/// - display
/// - filter
///
/// PERFOMANCE: cache?

enum PropType {
  recommend('recommend'),
  recentActivity('recentActivity'),
  numComments('numComments');

  const PropType(this.label);
  final String label;
}

// DEFER: There's probably a better way to do this (factories, enums, ...)
Map<PropType, Prop> cloners = {
  PropType.recommend: RecommendPropAggregator(),
  PropType.recentActivity: RecentActivityAggregator(),
  PropType.numComments: CommentsAggregator(),
};

abstract class Prop {
  Prop clone();
  void process(ContentStatement statement);

  bool get recurse;

  /// selective: include children / don't include children

  Comparable? get value;
  Widget getWidget();
}

class RecommendPropAggregator implements Prop {
  int count = 0;

  @override
  clone() => RecommendPropAggregator();

  @override
  bool get recurse => false;

  @override
  void process(ContentStatement statement) {
    if (b(statement.recommend)) {
      count += statement.recommend! ? 1 : -1;
    }
  }

  @override
  Comparable? get value => count;

  @override
  Widget getWidget() {
    String s;
    if (count == 0) {
      s = '';
    } else if (count > 0) {
      s = '+$count';
    } else {
      s = count.toString();
    }
    return Tooltip(
        message: 'count(recommend) = $count',
        child:
            SizedBox(width: 26, child: Text(s, style: const TextStyle(color: Colors.deepOrange))));
  }
}

class RecentActivityAggregator implements Prop {
  DateTime? recent;

  @override
  Prop clone() => RecentActivityAggregator();

  @override
  bool get recurse => true;

  @override
  void process(ContentStatement statement) {
    DateTime datetime = statement.time;
    if (recent == null || datetime.isAfter(recent!)) {
      recent = datetime;
    }
  }

  @override
  Comparable? get value => recent;

  @override
  Widget getWidget() {
    String s = recent != null ? formatUiDatetime(recent!) : '';
    return Tooltip(
        message: "recent activity",
        child: SizedBox(
            width: 100,
            child: Text(
              s,
              style: const TextStyle(color: Colors.green),
            )));
  }
}

class CommentsAggregator implements Prop {
  int numComments = 0;

  @override
  Prop clone() => CommentsAggregator();

  // Should the computation include children of children and more or just children.
  @override
  bool get recurse => true;

  // QUESTION: Could this be changed to take the SubjectNode, not just
  // its subject, so that we can decide to not process equivalents?
  @override
  void process(ContentStatement statement) {
    if (b(statement.comment)) numComments++;
  }

  @override
  Comparable? get value => numComments;

  @override
  Widget getWidget() {
    return Tooltip(
        message: "count(comments) = $numComments",
        child: SizedBox(
            width: 20,
            child: Text(
              numComments == 0 ? '' : '($numComments)',
              style: const TextStyle(color: Color.fromARGB(255, 143, 53, 18)),
              overflow: TextOverflow.ellipsis,
            )));
  }
}
