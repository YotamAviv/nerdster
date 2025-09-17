// Author: Grok
final RegExp tagRegExp = RegExp(r'(?<!#)\B#[a-zA-Z][\w]*(?:[\-_][\w]+)*\b');

Iterable<String> extractTags(String comment) {
  return tagRegExp.allMatches(comment).map((match) => match.group(0)!.toLowerCase());
}
