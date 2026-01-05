import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:nerdster/content/tag.dart';

// Author: Grok
// CODE: Should probably be in ContentTile file.

typedef OnHashtagTap = void Function(String hashtag, BuildContext context);

class CommentWidget extends StatelessWidget {
  final String text;
  final OnHashtagTap? onHashtagTap;
  final TextStyle? style;
  final int? maxLines;

  const CommentWidget({
    super.key,
    required this.text,
    this.onHashtagTap,
    this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (maxLines != null) {
      return Linkify(
        text: text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        linkifiers: [_HashtagLinkifier()],
        onOpen: (LinkableElement link) => onHashtagTap?.call(link.url, context),
        linkStyle: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      );
    }

    return SelectableLinkify(
      text: text,
      style: style,
      linkifiers: [_HashtagLinkifier()],
      onOpen: (LinkableElement link) => onHashtagTap?.call(link.url, context),
      linkStyle: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

class _HashtagLinkifier extends Linkifier {
  @override
  List<LinkifyElement> parse(List<LinkifyElement> elements, LinkifyOptions options) {
    final List<LinkifyElement> result = [];

    for (final LinkifyElement element in elements) {
      if (element is TextElement) {
        final Iterable<RegExpMatch> matches = tagRegExp.allMatches(element.text);
        int currentIndex = 0;

        for (final RegExpMatch match in matches) {
          final String prefix = element.text.substring(currentIndex, match.start);
          if (prefix.isNotEmpty) {
            result.add(TextElement(prefix));
          }

          final String hashtag = match.group(0)!;
          result.add(LinkableElement(hashtag, hashtag.toLowerCase()));

          currentIndex = match.end;
        }

        if (currentIndex < element.text.length) {
          final String suffix = element.text.substring(currentIndex);
          result.add(TextElement(suffix));
        }
      } else {
        result.add(element);
      }
    }

    return result;
  }
}
