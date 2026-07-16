import 'package:flutter/material.dart';
import 'package:nerdster/ui/util/linky.dart';
import 'package:nerdster/ui/util_ui.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/version.dart';

// CODE: Duplicated from Oneofus
class About extends StatelessWidget {
  static const About singleton = About._internal();
  const About._internal();

  static Future<void> show(BuildContext context) async {
    return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          final mediaSize = MediaQuery.of(context).size;
          // Phones are too narrow for width/2 (text wraps taller and clips the version at the
          // bottom). Use most of the width on small screens, and cap height + scroll so content
          // always fits.
          final double width = mediaSize.width < 600 ? mediaSize.width * 0.9 : mediaSize.width / 2;
          return Dialog(
              shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
              child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width, maxHeight: mediaSize.height * 0.8),
                  child: singleton));
        });
  }

  static Future<void> init() async {}

  @override
  Widget build(BuildContext context) {
    int taps = 0;
    return SafeArea(
      child: Padding(
        padding: kPadding,
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nerdster', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Linky('Home: https://nerdster.org'),
            Linky('Embed or access: https://nerdster.org/app'),
            Linky('Contact: contact@nerdster.org'),
            const SizedBox(height: 8),
            Linky('Privacy Policy: https://nerdster.org/policy.html'),
            Linky('Terms of Service: https://nerdster.org/terms.html'),
            Linky('Safety & Content Policy: https://nerdster.org/safety.html'),
            const SizedBox(height: 8),
            Linky(
                'Movie posters and data from TMDB (https://www.themoviedb.org). This product uses the TMDB API but is not endorsed or certified by TMDB.'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                taps++;
                if (taps >= 7 && !Setting.get<bool>(SettingType.dev).value) {
                  Setting.get<bool>(SettingType.dev).value = true;
                  const String message = 'You are now a developer.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(message)),
                  );
                  debugPrint(message);
                }
              },
              child: const Text('Version: $kAppVersion'),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
