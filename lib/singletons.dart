import 'package:flutter/foundation.dart';
import 'package:nerdster/sign_in_state.dart';
import 'package:nerdster/v2/labeler.dart';
import 'package:nerdster/oneofus/keys.dart';

import 'package:nerdster/v2/model.dart';

final SignInState signInState = SignInState();
final ValueNotifier<V2Labeler> globalLabeler = ValueNotifier(V2Labeler(TrustGraph(pov: IdentityKey('anonymous'))));
