import 'package:nerdster/utils/tag.dart';
import 'package:flutter_test/flutter_test.dart';

// From
// Letter after #: Use [a-zA-Z] to ensure the first character is a letter.
// Allow hyphens/underscores: Use (?:[\-_][\w]+)* to allow optional groups of hyphen/underscore followed by word characters.
// Standalone hashtags: Use \B (non-word boundary before #) and \b (word boundary after hashtag) to reject embedded hashtags.
// Combined RegExp: r'\B#[a-zA-Z][\w]*(?:[\-_][\w]+)*\b'

// Matches: #hashtag, #Flutter, #tag123, #my-tag, #my_new_tag, #a
// Rejects: #123 (no letter first), text#tag (embedded), ##tag (extra #), # (empty), #tag-hyphen (trailing hyphen)

void main() async {
  test('base', () {
    expect(extractTags('comment'), <String>{});

    // reject
    expect(extractTags('#123'), <String>{});
    expect(extractTags('text#tag'), <String>{});
    expect(extractTags('##tag'), <String>{});
    expect(extractTags('#'), <String>{});

    // accept
    expect(extractTags('#Flutter'), <String>{'#flutter'});
    expect(extractTags('#tag123'), <String>{'#tag123'});
    expect(extractTags('#my-tag'), <String>{'#my-tag'});
    expect(extractTags('#my_new_tag'), <String>{'#my_new_tag'});

    expect(extractTags('comment #@34'), <String>{});
    expect(extractTags('comment #word'), {'#word'});
    expect(extractTags('comment #Word'), {'#word'});
    expect(extractTags('comment # #Word'), {'#word'});
    expect(extractTags('comment #Word'), {'#word'});
    expect(extractTags('comment #Word #5'), {'#word'});
    expect(extractTags('comment #Word123abc'), {'#word123abc'});
    expect(extractTags('comment #Word #word'), {'#word'});
    expect(extractTags('comment #Word stuff #otherword'), {'#word', '#otherword'});
  });
}
