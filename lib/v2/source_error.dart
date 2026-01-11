class SourceError {
  final String reason;
  final String? token; // The Identity/Delegate token involved, if known
  final dynamic originalError; // The underlying exception

  SourceError(this.reason, {this.token, this.originalError});

  @override
  String toString() => 'SourceError($token): $reason';
}
