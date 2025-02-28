import 'package:nerdster/comp.dart';
import 'package:nerdster/content/content_tree_node.dart';
import 'package:nerdster/demotest/demo_key.dart';
import 'package:nerdster/demotest/demo_util.dart';
import 'package:nerdster/demotest/test_clock.dart';
import 'package:nerdster/dump_and_load.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/statement.dart';
import 'package:nerdster/oneofus/trust_statement.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

Future<(DemoKey, DemoKey?)> delegateMerge() async {
    useClock(TestClock());

    Iterable<ContentTreeNode> roots;
    var expected;
    DemoKey somebodyElse = await DemoKey.findOrCreate('somebodyElse');

    DemoKey loner = await DemoKey.findOrCreate('loner');
    DemoKey lonerN = await loner.makeDelegate();
    Statement n1 = await lonerN.doRate(title: 't1');

    DemoKey lonerN2 = await loner.makeDelegate();
    Statement s1 = await loner.doTrust(TrustVerb.block, somebodyElse);
    Statement n2 = await lonerN2.doRate(title: 't2');

    signInState.center = loner.token;
    await Comp.waitOnComps([contentBase, keyLabels]);
    expected = {"Me": null};
    jsonShowExpect(dumpNetwork(oneofusNet.network), expected);
    roots = contentBase.roots;
    myExpect(roots.length, 2);

    DemoKey loner2 = await DemoKey.findOrCreate('loner2');
    await loner2.doTrust(TrustVerb.replace, loner, revokeAt: s1.token);
    oneofusNet.listen();
    signInState.center = loner2.token;
    await Comp.waitOnComps([contentBase, keyLabels]);
    expected = {"Me": null, "Me (0)": "5/1/2024 12:04 AM"};
    jsonShowExpect(dumpNetwork(oneofusNet.network), expected);
    expected = {"Me": 2};
    jsonShowExpect(
        followNet.oneofus2delegates.map((key, value) => MapEntry(key, value.length)), expected);
    roots = contentBase.roots;
    myExpect(roots.length, 2);

    DemoKey loner2N = await loner2.makeDelegate();
    followNet.listen();
    Statement s3 = await loner2N.doRate(title: 't3');
    contentBase.listen();
    await Comp.waitOnComps([contentBase]);
    roots = contentBase.roots;
    myExpect(roots.length, 3);

    DemoKey loner2N2 = await loner2.makeDelegate();
    followNet.listen();
    Statement s4 = await loner2N2.doRate(title: 't4');
    contentBase.listen();
    await Comp.waitOnComps([contentBase]);
    roots = contentBase.roots;
    myExpect(roots.length, 4);

    // --- 2 equiv Oneofus, with 2 active delegates each, ready to merge.. --- //

    assert(oneofusNet.ready);
    expected = {"Me": null, "Me (0)": "5/1/2024 12:04 AM"};
    jsonShowExpect(dumpNetwork(oneofusNet.network), expected);

    assert(followNet.ready);
    expected = {"Me": 4};
    jsonShowExpect(
        followNet.oneofus2delegates.map((key, value) => MapEntry(key, value.length)), expected);

    // confirmed
    await lonerN.doRate(title: 'merge');
    await lonerN2.doRate(title: 'merge');
    await loner2N.doRate(title: 'merge');
    await loner2N2.doRate(title: 'merge');
    contentBase.listen();
    await Comp.waitOnComps([contentBase]);
    roots = contentBase.roots;

    myExpect(roots.length, 5);

    // 'merge' title should have 1 child
    assert(roots.where((n) => n.subject['title'] == 'merge').length == 1);
    ContentTreeNode mergeTreeNode = roots.where((n) => n.subject['title'] == 'merge').first;
    assert(mergeTreeNode.getChildren().length == 1, mergeTreeNode.getChildren().length);

    useClock(clock);
    return (loner2, loner2N2);
}

