import 'dart:js_interop';

import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/prefs.dart';
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
            final identity = jsonData['identity'].cast<String, dynamic>();
            print('Identity: $identity');
            final token = getToken(identity);
            print('Token: $token');
            // TODO: Show progress
            signInState.center = token;
          }

          for (final setting in Setting.all) {
            if (jsonData.containsKey(setting.name)) {
              setting.updateFromQueryParam({setting.name: jsonData[setting.name].toString()});
            }
          }
        }
      }.toJS);
}
