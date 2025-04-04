import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';

Map<FireChoice, Map<String, String>> streamstatementsUrl = {
  FireChoice.prod: {
    kOneofusDomain: 'http://us-central1-one-of-us-net.cloudfunctions.net/streamstatements',
    kNerdsterDomain: 'http://us-central1-one-of-us-net.cloudfunctions.net/streamstatements'
  },
  FireChoice.emulator: {
    kOneofusDomain: 'http://127.0.0.1:5001/one-of-us-net/us-central1/streamstatements',
    kNerdsterDomain: 'http://127.0.0.1:5001/nerdster/us-central1/streamstatements'
  },
};


Map<FireChoice, Map<String, String>> streamnumsUrl = {
  FireChoice.prod: {
    kOneofusDomain: 'http://us-central1-one-of-us-net.cloudfunctions.net/streamnums',
    kNerdsterDomain: 'http://us-central1-one-of-us-net.cloudfunctions.net/streamnums'
  },
  FireChoice.emulator: {
    kOneofusDomain: 'http://127.0.0.1:5001/one-of-us-net/us-central1/streamnums',
    kNerdsterDomain: 'http://127.0.0.1:5001/nerdster/us-central1/streamnums'
  },
};

void readStream() async {
  var client = http.Client();
  try {
    final Uri uri = Uri.parse(streamnumsUrl[fireChoice]![kNerdsterDomain]!);
    final http.Request request = http.Request('GET', uri);
    final http.StreamedResponse response = await client.send(request);
    assert(response.statusCode == 200, 'Request failed with status: ${response.statusCode}');
    response.stream.listen((value) {
      String data = String.fromCharCodes(value);
      Json json = jsonDecode(data);
      print('data=${json["data"]}');
    }, onError: (error) {
      print('Error in stream: $error');
    }, onDone: () {
      client.close();
    });
  } catch (e) {
    print('Error: $e');
  }
}
