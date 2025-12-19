import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:nerdster/net/net_tree.dart';
import 'package:nerdster/net/net_tree_model.dart';
import 'package:nerdster/v2/net_tree_model.dart';

class V2NetTreeView extends StatefulWidget {
  final V2NetTreeModel root;

  const V2NetTreeView({super.key, required this.root});

  @override
  State<V2NetTreeView> createState() => _V2NetTreeViewState();
}

class _V2NetTreeViewState extends State<V2NetTreeView> {
  late final TreeController<NetTreeModel> treeController;

  @override
  void initState() {
    super.initState();
    treeController = TreeController<NetTreeModel>(
      roots: [widget.root],
      childrenProvider: (NetTreeModel node) => node.children,
    );
    treeController.expand(widget.root);
  }

  @override
  void dispose() {
    treeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('V2 Trust Tree')),
      body: SafeArea(
        child: NetTreeTree(treeController: treeController),
      ),
    );
  }
}
