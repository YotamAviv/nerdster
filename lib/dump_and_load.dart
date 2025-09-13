import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_statement.dart';
import 'package:nerdster/main.dart';
import 'package:nerdster/net/oneofus_tree_node.dart';
import 'package:nerdster/oneofus/fetcher.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ok_cancel.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/trust/trust.dart';

// formats time, leaves tokens alone.
Map<String, String?> dumpNetwork(Map<String, Node> network) => network.map((token, node) =>
    MapEntry(token, b(node.revokeAtTime) ? formatUiDatetime(node.revokeAtTime!) : null));

Future<Json> dumpDump(BuildContext? context) async {
  await Comp.waitOnComps([keyLabels, contentBase]);

  Json out = {
    'center': Jsonish.find(signInState.pov!)!.json,
    'domain2token2statements': await dumpStatements(),
    // Above is required for importing.
    // Below is for strictly for testing / viewing.
    'network': dumpNetwork(oneofusNet.network),
    'nerds': await OneofusTreeNode.root.dump(),
    'content': contentBase.dump(),
    // 'netTree': NetTreeNode.root.dump(),
    // 'contentTree': contentBase.dump(),
  };

  if (context != null) {
    _showDump(context, out);
  }
  return out;
}

dynamic loadDumpDialog(BuildContext context) async {
  if (fireChoice == FireChoice.prod) throw 'not on production';

  TextEditingController controller = TextEditingController();

  okHandler() {
    Json dump = jsonDecode(controller.text);
    loadDump(dump);
    Navigator.pop(context);
  }

  await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
              child: Column(children: [
            TextField(
                controller: controller,
                maxLines: 30,
                style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black)),
            const SizedBox(height: 10),
            OkCancel(okHandler, 'Process statements'),
          ])));
}

Future<void> loadDump(Json dump) async {
  dynamic token2domain2statements = dump['domain2token2statements'];
  await loadStatements(token2domain2statements);
  signInState.pov = Jsonish(dump['center']).token;
}

Future<void> loadStatements(Json domain2token2statements) async {
  for (String domain in [kOneofusDomain, kNerdsterDomain]) {
    for (MapEntry e in domain2token2statements[domain]!.entries) {
      String token = e.key;
      List jsons = e.value;
      for (Json json in jsons.reversed) {
        // load oldest to newest (order they were stated)
        Fetcher fetcher = Fetcher(token, domain);
        // Here we're pushing JSON that already has 'signature' and 'previous'.
        await fetcher.push(json, null);
      }
    }
  }
}

Future<Map<String, Map<String, List>>> dumpStatements() async {
  await followNet.waitUntilReady();

  Map<String, Map<String, List>> out = <String, Map<String, List>>{};
  Map<String, List> map = <String, List>{};
  out[kOneofusDomain] = map;
  for (String token in oneofusNet.network.keys) {
    List list = [];
    map[token] = list;
    Fetcher fetcher = Fetcher(token, kOneofusDomain);
    for (final Statement statement in await fetcher.fetchAllNoVerify()) {
      list.add(statement.json);
    }
  }

  Map<String, List> map2 = <String, List>{};
  out[kNerdsterDomain] = map2;
  for (MapEntry e in followNet.delegate2fetcher.entries) {
    final String token = e.key;
    final Fetcher fetcher = e.value;
    List list = [];
    map2[token] = list;
    for (final Statement statement in await fetcher.fetchAllNoVerify()) {
      list.add(statement.json);
    }
  }
  return out;
}

_showDump(BuildContext context, dynamic dump) {
  ScrollController scrollController = ScrollController();
  showDialog(
      context: context,
      builder: (context) => Dialog(
          child: Scrollbar(
              controller: scrollController,
              child: TextField(
                  scrollController: scrollController,
                  controller: TextEditingController()..text = encoder.convert(dump),
                  maxLines: 30,
                  readOnly: true,
                  style: GoogleFonts.courierPrime(fontSize: 12, color: Colors.black)))));
}
