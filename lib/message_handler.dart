import 'dart:js_interop';

import 'package:nerdster/app.dart';
import 'package:oneofus_common/jsonish.dart';
import 'package:nerdster/settings/prefs.dart';
// import 'package:nerdster/content/content_tree.dart';
import 'package:nerdster/singletons.dart';
import 'package:web/web.dart' as web;

void initMessageListener() {
  web.window.addEventListener(
      'message',
      (web.Event event) {
        final messageEvent = event as web.MessageEvent;
        final data = messageEvent.data.dartify();
        print('Received message: $data');
        if (data is Map) {
          final jsonData = data.cast<String, dynamic>();
          if (jsonData.containsKey('identity') && jsonData['identity'] is Map) {
            final Json identity = jsonData['identity'].cast<String, dynamic>();
            print('Identity: $identity');
            final token = getToken(identity);
            print('Token: $token');

            Future.microtask(() async {
              await signInState.signIn(token, null);
            });
          }

          for (final Setting setting in Setting.all) {
            if (jsonData.containsKey(setting.name)) {
              setting.updateFromQueryParam({setting.name: jsonData[setting.name].toString()});
              // Don't: setting.resetToDefault();
            }
          }
        }
      }.toJS);
}
