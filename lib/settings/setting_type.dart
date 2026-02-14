import 'package:nerdster/logic/follow_logic.dart';

enum SettingType {
  lgtm(bool, false),
  identityPathsReq(String, 'permissive'),
  fcontext(String, kFollowContextNerdster, aliases: ['follow']),

  censor(bool, true),
  dis(String, 'my'),
  sort(String, 'recentActivity'),
  contentType(String, 'all', aliases: ['type']),
  timeframe(String, 'all'),
  tag(String, '-'),

  showCrypto(bool, false),
  dev(bool, false),

  skipVerify(bool, true),

  verifyImmediately(bool, false, param: true),
  verify(String, null, param: true),

  debugUseSubjectNotToken(bool, false);

  final Type type;
  final dynamic defaultValue;
  final List<String> aliases;
  final bool persist;
  final bool param;

  const SettingType(this.type, this.defaultValue,
      {this.aliases = const [], this.persist = false, this.param = true});
}
