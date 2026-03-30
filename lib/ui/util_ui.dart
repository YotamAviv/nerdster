import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color linkColor = Colors.blueAccent;
final Color linkColorAlready = Colors.blue.shade900;
final Color linkColorDisabled = Colors.blue.shade200;
const TextStyle hintStyle = TextStyle(color: Colors.black26);
const TextStyle linkStyle = TextStyle(color: linkColor, decoration: TextDecoration.underline);

/// Launch a URL in the external browser. App Link interception for
/// nerdster.org is no longer an issue since the App Link filter is
/// restricted to /app paths only.
Future<void> myLaunchUrl(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

const kPadding = EdgeInsets.all(4);
const kTallPadding = EdgeInsets.fromLTRB(0, 8, 0, 4);
const BorderRadius kBorderRadius = BorderRadius.all(Radius.circular(8));
