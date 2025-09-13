
// Example comment processing
Set<String> extractTags(String comment) {
  final RegExp tagRegExp = RegExp(r'#[\w]+');
  return tagRegExp
      .allMatches(comment)
      .map((match) => match.group(0)!.toLowerCase())
      .toSet();
}