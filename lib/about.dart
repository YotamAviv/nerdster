import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:package_info_plus/package_info_plus.dart';

class About {
  static late final PackageInfo _packageInfo;

  static Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  static show(BuildContext context) {
    String body = 
'''
Home: https://nerdster.org

Version: ${_packageInfo.version}
Build number: ${_packageInfo.buildNumber}
''';
    alert('''Nerd'ster''', body, ['Okay'], context);
  }
}
