import 'package:flutter/foundation.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:oneofus_common/keys.dart';

import 'package:nerdster/models/model.dart';

final SignInState signInState = SignInState();
final ValueNotifier<V2Labeler> globalLabeler =
    ValueNotifier(V2Labeler(TrustGraph(pov: IdentityKey('anonymous'))));
