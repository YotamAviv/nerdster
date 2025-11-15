import 'dart:js_interop';

import 'package:nerdster/bar_refresh.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/content/content_tree.dart';
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

            final context = ContentTree.rootContext;
            final state = ContentTree.contentKey.currentState;
            if (!(state != null && state.mounted && context != null)) return;
            Future.microtask(() async {
              if (!state.mounted) return;
              await signInState.signIn(token, null, context: context);
              await BarRefresh.refresh(context);
            });
          }

          for (final Setting setting in Setting.all) {
            if (jsonData.containsKey(setting.name)) {
              setting.updateFromQueryParam({setting.name: jsonData[setting.name].toString()});
            } else {
              setting.resetToDefault();
            }
          }
        }
      }.toJS);
}
