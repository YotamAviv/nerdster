
import 'package:nerdster/follow/follow_net.dart';

enum SettingType {
  skipLgtm(bool, false, persist: true),
  skipCredentials(bool, false, persist: true),
  identityNetDegrees(int, 5, aliases: ['oneofusNetDegrees']),
  identityNetPaths(int, 1, aliases: ['oneofusNetPaths']),
  followNetDegrees(int, 5),
  followNetPaths(int, 1),

  censor(bool, true),
  hideDisliked(bool, false),
  dis(String, 'pov'),
  sort(String, 'recentActivity'),
  contentType(String, 'all', aliases: ['type']),
  timeframe(String, 'all'),
  tag(String, '-'),

  fcontext(String, kNerdsterContext, aliases: ['follow']),

  netView(bool, false),

  showCrypto(bool, false, aliases: ['showStuff']),
  showJson(bool, false, param: false),
  showKeys(bool, false, param: false),
  showStatements(bool, false, param: false),
  dev(bool, false),
  bogus(bool, true),

  skipVerify(bool, true),
  httpFetch(bool, true),
  batchFetch(bool, true);

  final Type type;
  final dynamic defaultValue;
  final List<String> aliases;
  final bool persist;
  final bool param;

  const SettingType(this.type, this.defaultValue,
      {this.aliases = const [], this.persist = false, this.param = true});
}
