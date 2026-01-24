import 'package:nerdster/v2/follow_logic.dart';

enum SettingType {
  skipLgtm(bool, false, persist: true),
  identityPathsReq(String, 'permissive'),
  fcontext(String, kFollowContextNerdster, aliases: ['follow']),

  censor(bool, true),
  hideDisliked(bool, false),
  hideSeen(bool, false, persist: true),
  dis(String, 'pov'),
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
