import 'package:flutter/material.dart';
import 'package:nerdster/demotest/cases/v2_scenarios.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster/v2/shadow_view.dart';

Future<void> runV2Scenario1(BuildContext context) async {
  var keys = await setupGracefulRecovery();
  var aliceToken = keys['alice']!.token;
  
  signInState.pov = aliceToken;
  
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShadowView(rootToken: aliceToken),
      ),
    );
  }
}

Future<void> runV2Scenario2(BuildContext context) async {
  var keys = await setupPersistentBlock();
  var aliceToken = keys['alice']!.token;
  
  signInState.pov = aliceToken;
  
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShadowView(rootToken: aliceToken),
      ),
    );
  }
}

Future<void> runV2Scenario4(BuildContext context) async {
  var keys = await setupMutualFriendConflict();
  var aliceToken = keys['alice']!.token;
  
  signInState.pov = aliceToken;
  
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShadowView(rootToken: aliceToken),
      ),
    );
  }
}

Future<void> runV2Scenario5(BuildContext context) async {
  var keys = await setupLostKey();
  var aliceToken = keys['alice']!.token;
  
  signInState.pov = aliceToken;
  
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShadowView(rootToken: aliceToken),
      ),
    );
  }
}

Future<void> runV2Scenario6(BuildContext context) async {
  var keys = await setupPoorJudgment();
  var aliceToken = keys['alice']!.token;
  
  signInState.pov = aliceToken;
  
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShadowView(rootToken: aliceToken),
      ),
    );
  }
}

Future<void> runV2Scenario7(BuildContext context) async {
  var keys = await setupWhacAMole();
  var aliceToken = keys['alice']!.token;
  
  signInState.pov = aliceToken;
  
  if (context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShadowView(rootToken: aliceToken),
      ),
    );
  }
}
