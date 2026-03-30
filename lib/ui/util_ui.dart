import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color linkColor = Colors.blueAccent;
final Color linkColorAlready = Colors.blue.shade900;
final Color linkColorDisabled = Colors.blue.shade200;
const TextStyle hintStyle = TextStyle(color: Colors.black26);
const TextStyle linkStyle = TextStyle(color: linkColor, decoration: TextDecoration.underline);

/// Launch a URL using Chrome Custom Tabs on Android (to avoid App Link
/// interception on self-verified domains like nerdster.org) and the external
/// browser on iOS/web.
Future<void> myLaunchUrl(String url) async {
  final uri = Uri.parse(url);
  final mode = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? LaunchMode.inAppBrowserView
      : LaunchMode.externalApplication;
  await launchUrl(uri, mode: mode);
}

const kPadding = EdgeInsets.all(4);
const kTallPadding = EdgeInsets.fromLTRB(0, 8, 0, 4);
const BorderRadius kBorderRadius = BorderRadius.all(Radius.circular(8));
