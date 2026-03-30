import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color linkColor = Colors.blueAccent;
final Color linkColorAlready = Colors.blue.shade900;
final Color linkColorDisabled = Colors.blue.shade200;
const TextStyle hintStyle = TextStyle(color: Colors.black26);
const TextStyle linkStyle = TextStyle(color: linkColor, decoration: TextDecoration.underline);

/// Launch a URL in a way that is never intercepted by the app's own App Link
/// filter (https://nerdster.org). On Android we use inAppWebView (a raw
/// Flutter WebView) because Chrome Custom Tabs still route through Chrome's
/// App Link logic and may redirect back to the app. iOS and web use the
/// standard external browser.
Future<void> myLaunchUrl(String url) async {
  final uri = Uri.parse(url);
  final mode = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? LaunchMode.inAppWebView
      : LaunchMode.externalApplication;
  await launchUrl(uri, mode: mode);
}

const kPadding = EdgeInsets.all(4);
const kTallPadding = EdgeInsets.fromLTRB(0, 8, 0, 4);
const BorderRadius kBorderRadius = BorderRadius.all(Radius.circular(8));
