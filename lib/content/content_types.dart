import 'package:flutter/material.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';

enum ContentType {
  all('all', Icon(Icons.star)),
  article('article', Icon(Icons.article)),
  book('book', Icon(Icons.book)),
  movie('movie', Icon(Icons.movie)),
  video('video', Icon(Icons.video_library)),
  podcast('podcast', Icon(Icons.podcasts)),
  album('album', Icon(Icons.library_music)),
  recipe('recipe', Icon(Icons.restaurant, color: Colors.brown,)), // CONSIDER: colors
  event('event', Icon(Icons.event)),
  resource('resource', Icon(Icons.rss_feed));

  const ContentType(this.label, this.icon);
  final String label;
  final Icon icon;
}

/// CONSIDER: Separate and move to the [SubjectTile], [NerdTile]
/// Then again, it's good to have the various things related to types in one place.
final Map<String, List<IconData>> tileType2icon = {
  kOneofusType: [Icons.attachment_outlined, Icons.attachment],
  kNerdsterType: [Icons.attachment_outlined, Icons.attachment],

  'nerd': [Icons.sentiment_satisfied_outlined, Icons.sentiment_satisfied],
  'key': [Icons.key_outlined, Icons.key],
  
  'article': [Icons.article_outlined, Icons.article],
  'book': [Icons.book_outlined, Icons.book],
  'movie': [Icons.movie_outlined, Icons.movie],
  'video': [Icons.video_library_outlined, Icons.video_library],
  'podcast': [Icons.podcasts_outlined, Icons.podcasts],
  'album': [Icons.library_music_outlined, Icons.library_music],
  'event': [Icons.event_outlined, Icons.event],
  'recipe': [Icons.restaurant_outlined, Icons.restaurant],  
  'resource': [Icons.rss_feed_outlined, Icons.rss_feed],
};

// TODO: Use the enum
const Map<String, List<Map<String, String>>> contentType2field2type =
    <String, List<Map<String, String>>>{
  'article': [
    {'url': 'url'},
    {'title': 'string'},
  ],
  'movie': [
    {'title': 'string'},
    {'year': 'number'},
  ],
  'video': [
    {'url': 'url'},
    {'title': 'string'},
  ],
  'podcast': [
    {'url': 'url'},
    {'title': 'string'},
  ],
  'album': [
    {'title': 'string'},
    {'artist': 'string'},
    {'year': 'number'},
  ],
  'book': [
    {'title': 'string'},
    {'author': 'string'},
  ],
  'recipe': [
    {'url': 'url'},
    {'title': 'string'},
  ],
  'event': [
    {'url': 'url'},
    {'title': 'string'},
    {'time': 'time'},
    {'location': 'string'},
  ],
  'resource': [
    {'url': 'url'},
    {'title': 'string'},
  ],
};

