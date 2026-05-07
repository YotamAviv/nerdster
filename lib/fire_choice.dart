import 'package:oneofus_common/channel_factory.dart';

export 'package:oneofus_common/channel_factory.dart' show ChannelFactory, channelFactory, FireChoice;

// Convenience getter so existing call sites that read fireChoice still compile.
// Write sites (fireChoice = ...) must be migrated to create a new ChannelFactory.
FireChoice get fireChoice => channelFactory.fireChoice;
