import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nerdster/main.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/content/content_statement.dart';

Map<FireChoice, Map<String, (String, String)>> streamnumsUrl = {
  FireChoice.prod: {
    kOneofusDomain: ('us-central1-one-of-us-net.cloudfunctions.net', 'streamnums'),
    kNerdsterDomain: ('us-central1-nerdster.cloudfunctions.net', 'streamnums')
  },
  FireChoice.emulator: {
    kOneofusDomain: ('127.0.0.1:5001', 'one-of-us-net/us-central1/streamnums'),
    kNerdsterDomain: ('127.0.0.1:5001', 'nerdster/us-central1/streamnums')
  },
};

void readStream() async {
  var client = http.Client();
  try {
    String host = streamnumsUrl[fireChoice]![kNerdsterDomain]!.$1;
    String path = streamnumsUrl[fireChoice]![kNerdsterDomain]!.$2;
    // TODO: https instead of http, currently doesn't work
    // TODO: Wierd: only http works on emulator, only https works on PROD
    Uri uri = (fireChoice == FireChoice.prod) ? Uri.https(host, path) : Uri.http(host, path);
    final http.Request request = http.Request('GET', uri);
    // request.headers['Accept'] = 'application/json'; // TEMP, uncomment

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
