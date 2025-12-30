import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/prefs.dart';
import 'package:nerdster/setting_type.dart';
import 'package:nerdster/v2/cloud_functions_source.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/lgtm_writer.dart';

class SourceFactory {
  static StatementSource<T> get<T extends Statement>(String domain) =>
      (fireChoice == FireChoice.fake ||
              !Setting.get<bool>(SettingType.httpFetch).value)
          ? DirectFirestoreSource<T>(FireFactory.find(domain))
          : CloudFunctionsSource<T>(baseUrl: V2Config.getUrl(domain)!);

  static StatementWriter getWriter(String domain, {BuildContext? context}) {
    StatementWriter writer = DirectFirestoreWriter(FireFactory.find(domain));
    if (context != null) {
      return LgtmStatementWriter(writer, context);
    }
    return writer;
  }
}
