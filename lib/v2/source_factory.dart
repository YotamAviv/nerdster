import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/fire_choice.dart';
import 'package:nerdster/oneofus/fire_factory.dart';
import 'package:nerdster/oneofus/oou_verifier.dart';
import 'package:nerdster/v2/cloud_functions_source.dart';
import 'package:nerdster/v2/config.dart';
import 'package:nerdster/v2/direct_firestore_source.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/v2/lgtm_writer.dart';

import 'package:nerdster/v2/labeler.dart';

class SourceFactory {
  static StatementSource<T> get<T extends Statement>(String domain) =>
      (fireChoice == FireChoice.fake)
          ? DirectFirestoreSource<T>(FireFactory.find(domain))
          : CloudFunctionsSource<T>(
              baseUrl: FirebaseConfig.getUrl(domain)!,
              verifier: OouVerifier(),
            );

  static StatementWriter getWriter(String domain, {BuildContext? context, V2Labeler? labeler}) {
    StatementWriter writer = DirectFirestoreWriter(FireFactory.find(domain));
    if (context != null) {
      if (labeler == null) {
        throw ArgumentError('labeler is required when context is provided (for LGTM check)');
      }
      return LgtmStatementWriter(writer, context, labeler: labeler);
    }
    return writer;
  }
}
