import 'package:flutter/material.dart';

enum ContentType {
  all(
    'all',
    Icon(Icons.star),
    {'url': 'url', 'title': 'string'},
  ),
  article(
    'article',
    Icon(Icons.article),
    {'url': 'url', 'title': 'string'},
  ),
  book(
    'book',
    Icon(Icons.book),
    {'title': 'string', 'author': 'string'},
  ),
  movie(
    'movie',
    Icon(Icons.movie),
    {'title': 'string', 'year': 'number'},
  ),
  video(
    'video',
    Icon(Icons.video_library),
    {'url': 'url', 'title': 'string'},
  ),
  podcast(
    'podcast',
    Icon(Icons.podcasts),
    {'url': 'url', 'title': 'string'},
  ),
  album(
    'album',
    Icon(Icons.library_music),
    {'title': 'string', 'artist': 'string', 'year': 'number'},
  ),
  recipe(
    'recipe',
    Icon(
      Icons.restaurant,
      color: Colors.brown,
    ),
    {'url': 'url', 'title': 'string'},
  ), // CONSIDER: colors
  event(
    'event',
    Icon(Icons.event),
    {'url': 'url', 'title': 'string', 'time': 'time', 'location': 'string'},
  ),
  resource(
    'resource',
    Icon(Icons.rss_feed),
    {'url': 'url', 'title': 'string'},
  );

  const ContentType(
    this.label,
    this.icon,
    this.type2field2type,
  );
  final String label;
  final Icon icon;
  final Map<String, String> type2field2type;
}

/// CONSIDER: Separate and move to {[ContentTile], [NetTile]}. Or not.
final Map<String, (IconData, IconData)> tileType2icon = {
  'article': (Icons.article_outlined, Icons.article),
  'book': (Icons.book_outlined, Icons.book),
  'movie': (Icons.movie_outlined, Icons.movie),
  'video': (Icons.video_library_outlined, Icons.video_library),
  'podcast': (Icons.podcasts_outlined, Icons.podcasts),
  'album': (Icons.library_music_outlined, Icons.library_music),
  'event': (Icons.event_outlined, Icons.event),
  'recipe': (Icons.restaurant_outlined, Icons.restaurant),
  'resource': (Icons.rss_feed_outlined, Icons.rss_feed),
};
