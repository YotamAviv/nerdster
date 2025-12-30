import 'package:flutter/material.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/v2/io.dart';
import 'package:nerdster/content/dialogs/lgtm.dart';

/// A wrapper around [StatementWriter] that performs an LGTM check before pushing.
class LgtmStatementWriter implements StatementWriter {
  final StatementWriter _delegate;
  final BuildContext _context;

  LgtmStatementWriter(this._delegate, this._context);

  @override
  Future<Statement> push(Json json, StatementSigner signer) async {
    bool? proceed = await Lgtm.check(json, _context);
    if (proceed != true) {
      throw Exception('LGTM check failed or cancelled');
    }
    return _delegate.push(json, signer);
  }
}
