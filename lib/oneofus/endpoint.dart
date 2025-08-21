// endpoint.dart
import 'dart:convert';
import 'jsonish.dart';

class Endpoint {
  final String scheme;
  final String host;
  final int? port;
  final String path; // no leading slash needed

  const Endpoint(this.scheme, this.host, this.path, {this.port});

  factory Endpoint.fromJson(Json json) =>
      Endpoint(json['scheme'], json['host'], json['path'], port: json['port'] as int?);

  Json toJson() => {'host': host, 'path': path, if (port != null) 'port': port, 'scheme': scheme};

  Uri build(Json params) {
    final encodedParams = params.map(
      (k, v) => MapEntry(k, const JsonEncoder().convert(v)),
    );
    return Uri(scheme: scheme, host: host, port: port, path: path, queryParameters: encodedParams);
  }
}
