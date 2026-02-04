import 'dart:math';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class FanAlgorithm extends Algorithm {
  final String rootId;
  final double levelSeparation;
  final Map<String, Offset>? pinnedNodes;

  FanAlgorithm({
    required this.rootId,
    this.levelSeparation = 200,
    this.pinnedNodes,
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
      if (pinnedNodes != null && pinnedNodes!.containsKey(node.key?.value.toString())) {
        final pinned = pinnedNodes![node.key!.value.toString()]!;
        node.x = pinned.dx;
        node.y = pinned.dy;
        minX = min(minX, node.x);
        minY = min(minY, node.y);
        maxX = max(maxX, node.x);
        maxY = max(maxY, node.y);
        continue;
      }

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
      _layoutFan(child, adjacency, positions, visited, nodeDepths, childStartAngle, childEndAngle,
          shiftX, shiftY);
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
    var sourcePos = edge.source.position;
    var destinationPos = edge.destination.position;

    // Center edges
    final sourceCenter = Offset(sourcePos.dx + edge.source.width / 2, sourcePos.dy + edge.source.height / 2);
    final destinationCenter = Offset(destinationPos.dx + edge.destination.width / 2, destinationPos.dy + edge.destination.height / 2);

    // Only skip if both are zero, which is unlikely for a valid edge
    if (sourcePos == Offset.zero && destinationPos == Offset.zero) return;

    final path = Path();

    // Calculate vector from source to destination
    final vector = destinationCenter - sourceCenter;
    final distance = vector.distance;

    if (distance == 0) return; // Overlapping nodes

    final direction = vector / distance;

    // Adjust start and end points to be on the boundary of the nodes
    final sourceRadius = edge.source.width / 2;
    final destRadius = edge.destination.width / 2;

    final startPoint = sourceCenter + direction * sourceRadius;
    final endPoint = destinationCenter - direction * destRadius;

    path.moveTo(startPoint.dx, startPoint.dy);
    
    // Check if edge is dashed (from paint override)
    if (edge.paint != null && edge.paint!.style == PaintingStyle.stroke && edge.paint!.strokeCap == StrokeCap.butt) {
      // Draw dashed line
      const dashWidth = 5.0;
      const dashSpace = 5.0;
      double currentDistance = 0.0;
      while (currentDistance < distance) {
        final dashStart = startPoint + direction * currentDistance;
        final dashEnd = startPoint + direction * min(currentDistance + dashWidth, distance);
        path.moveTo(dashStart.dx, dashStart.dy);
        path.lineTo(dashEnd.dx, dashEnd.dy);
        currentDistance += dashWidth + dashSpace;
      }
    } else {
      path.lineTo(endPoint.dx, endPoint.dy);
    }

    final edgePaint = edge.paint ?? paint;
    canvas.drawPath(path, edgePaint);

    // Draw arrow head
    _drawArrowHead(canvas, startPoint, endPoint, edgePaint);
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
