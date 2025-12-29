import 'dart:math';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class FanAlgorithm extends Algorithm {
  final String rootId;
  final double levelSeparation;
  
  FanAlgorithm({
    required this.rootId,
    this.levelSeparation = 200,
    EdgeRenderer? edgeRenderer,
  }) {
    renderer = edgeRenderer ?? CurvedEdgeRenderer();
  }

  @override
  Size run(Graph? graph, double shiftX, double shiftY) {
    if (graph == null || graph.nodes.isEmpty) return Size.zero;

    Node? rootNode;
    for (final node in graph.nodes) {
      final key = node.key;
      if (key is ValueKey<String> && key.value == rootId) {
        rootNode = node;
        break;
      }
    }
    rootNode ??= graph.nodes.first;

    final Map<Node, List<Node>> adjacency = {};
    for (final edge in graph.edges) {
      adjacency.putIfAbsent(edge.source, () => []).add(edge.destination);
    }

    final Map<Node, Offset> positions = {};
    final Set<Node> visited = {rootNode};

    // Position root at (shiftX, shiftY)
    positions[rootNode] = Offset(shiftX, shiftY);

    // Use BFS to determine depth for each node to ensure shortest path radius
    final Map<Node, int> nodeDepths = {rootNode: 0};
    final List<Node> queue = [rootNode];
    final Set<Node> bfsVisited = {rootNode};
    
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final depth = nodeDepths[current]!;
      for (final neighbor in adjacency[current] ?? []) {
        if (!bfsVisited.contains(neighbor)) {
          bfsVisited.add(neighbor);
          nodeDepths[neighbor] = depth + 1;
          queue.add(neighbor);
        }
      }
    }

    _layoutFan(rootNode, adjacency, positions, visited, nodeDepths, 0, pi / 2, shiftX, shiftY);

    // Assign positions to nodes and calculate bounding box
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    const double margin = 100.0;
    int unreachableCount = 0;

    for (final node in graph.nodes) {
      Offset pos;
      if (positions.containsKey(node)) {
        pos = positions[node]!;
      } else {
        // Place unreachable nodes in a vertical line to the left or right
        pos = Offset(shiftX - 150, shiftY + (unreachableCount + 1) * 100);
        unreachableCount++;
      }
      
      node.x = pos.dx + margin;
      node.y = pos.dy + margin;
      minX = min(minX, node.x);
      minY = min(minY, node.y);
      maxX = max(maxX, node.x);
      maxY = max(maxY, node.y);
    }

    return Size(maxX + margin, maxY + margin);
  }

  void _layoutFan(
    Node parent,
    Map<Node, List<Node>> adjacency,
    Map<Node, Offset> positions,
    Set<Node> visited,
    Map<Node, int> nodeDepths,
    double startAngle,
    double endAngle,
    double shiftX,
    double shiftY,
  ) {
    final children = (adjacency[parent] ?? []).where((n) => !visited.contains(n)).toList();
    if (children.isEmpty) return;

    final angleRange = endAngle - startAngle;
    final angleStep = angleRange / (children.length + 1);

    for (int i = 0; i < children.length; i++) {
      final child = children[i];
      visited.add(child);

      final depth = nodeDepths[child] ?? 1;
      final radius = depth * levelSeparation;
      final angle = startAngle + (i + 1) * angleStep;
      final x = radius * cos(angle) + shiftX;
      final y = radius * sin(angle) + shiftY;

      positions[child] = Offset(x, y);

      // Recursively layout children with a narrower angle range to avoid overlap
      final childStartAngle = angle - angleStep / 2;
      final childEndAngle = angle + angleStep / 2;
      _layoutFan(child, adjacency, positions, visited, nodeDepths, childStartAngle, childEndAngle, shiftX, shiftY);
    }
  }

  @override
  void init(Graph? graph) {}

  @override
  void setDimensions(double width, double height) {}
}

class CurvedEdgeRenderer extends EdgeRenderer {
  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    final source = edge.source.position;
    final destination = edge.destination.position;
    final center = const Offset(100, 100); // Root position in FanAlgorithm

    // Only skip if both are zero, which is unlikely for a valid edge
    if (source == Offset.zero && destination == Offset.zero) return;

    final path = Path();
    path.moveTo(source.dx, source.dy);

    // Calculate a control point that curves "outwards" from the center
    final midPoint = Offset(
      (source.dx + destination.dx) / 2,
      (source.dy + destination.dy) / 2,
    );
    
    final vectorToMid = midPoint - center;
    // Push the control point outward to create a radial curve effect
    // The factor 1.2 makes it curve slightly outward.
    final cp = center + vectorToMid * 1.2;

    path.quadraticBezierTo(cp.dx, cp.dy, destination.dx, destination.dy);
    
    final edgePaint = edge.paint ?? paint;
    canvas.drawPath(path, edgePaint);

    // Draw arrow head
    _drawArrowHead(canvas, cp, destination, edgePaint);
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final double arrowSize = 12.0;
    final double angle = atan2(to.dy - from.dy, to.dx - from.dx);

    final path = Path();
    path.moveTo(to.dx, to.dy);
    path.lineTo(
      to.dx - arrowSize * cos(angle - pi / 6),
      to.dy - arrowSize * sin(angle - pi / 6),
    );
    path.moveTo(to.dx, to.dy);
    path.lineTo(
      to.dx - arrowSize * cos(angle + pi / 6),
      to.dy - arrowSize * sin(angle + pi / 6),
    );

    final arrowPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, arrowPaint);
  }
}

