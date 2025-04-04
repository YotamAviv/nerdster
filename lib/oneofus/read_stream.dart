import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nerdster/oneofus/jsonish.dart';

void readStream() async {
  var client = http.Client();
  try {
    final http.Request request =
        http.Request('GET', Uri.parse("http://127.0.0.1:5001/nerdster/us-central1/streamnums"));
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
