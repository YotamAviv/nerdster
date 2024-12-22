import 'package:flutter/material.dart';

enum ContentType {
  all(
    'all',
    (Icons.star, Icons.star_outline),
    {'url': 'url', 'title': 'string'},
  ),
  article(
    'article',
    (Icons.article, Icons.article_outlined),
    {'url': 'url', 'title': 'string'},
  ),
  book(
    'book',
    (Icons.book, Icons.book_outlined),
    {'title': 'string', 'author': 'string'},
  ),
  movie(
    'movie',
    (Icons.movie, Icons.movie_outlined),
    {'title': 'string', 'year': 'number'},
  ),
  video(
    'video',
    (Icons.video_library, Icons.video_library_outlined),
    {'url': 'url', 'title': 'string'},
  ),
  podcast(
    'podcast',
    (Icons.podcasts, Icons.podcasts_outlined),
    {'url': 'url', 'title': 'string'},
  ),
  album(
    'album',
    (Icons.library_music, Icons.library_music_outlined),
    {'title': 'string', 'artist': 'string', 'year': 'number'},
  ),
  recipe(
    'recipe',
    (
      Icons.restaurant, Icons.restaurant_outlined),
    {'url': 'url', 'title': 'string'},
  ), // CONSIDER: colors
  event(
    'event',
    (Icons.event, Icons.event_outlined),
    {'url': 'url', 'title': 'string', 'time': 'time', 'location': 'string'},
  ),
  resource(
    'resource',
    (Icons.rss_feed, Icons.rss_feed_outlined),
    {'url': 'url', 'title': 'string'},
  );

  const ContentType(
    this.label,
    this.iconDatas,
    this.type2field2type,
  );
  final String label;
  final (IconData, IconData) iconDatas;
  final Map<String, String> type2field2type;
}

