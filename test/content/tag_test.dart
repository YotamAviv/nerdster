import 'package:nerdster/content/tag.dart';
import 'package:test/test.dart';

void main() async {
  test('base', () {
    expect(extractTags('comment'), <String>{});
    expect(extractTags('comment #@34'), <String>{});
    expect(extractTags('comment #word'), {'#word'});
    expect(extractTags('comment #Word'), {'#word'});
    expect(extractTags('comment # #Word'), {'#word'});
    expect(extractTags('comment #Word'), {'#word'});
    expect(extractTags('comment #Word123abc'), {'#word123abc'});
    expect(extractTags('comment #Word #word'), {'#word'});
    expect(extractTags('comment #Word stuff #otherword'), {'#word', '#otherword'});
  });
}
