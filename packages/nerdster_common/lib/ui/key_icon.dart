import 'dart:math';

import 'package:flutter/material.dart';

enum KeyType { identity, delegate }
enum KeyStatus { active, revoked }

/// Three-state presence for key icons.
enum KeyPresence {
  owned,  // we hold the private key pair  → filled icon
  known,  // we have the public key only   → outlined icon
  absent, // we don't have the key at all  → ghost: outlined + 25% opacity
}

class KeyIcon extends StatelessWidget {
  final KeyType type;
  final KeyStatus status;
  final KeyPresence presence;
  final double? size;

  const KeyIcon({
    super.key,
    required this.type,
    this.status = KeyStatus.active,
    this.presence = KeyPresence.known,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = type == KeyType.identity ? Colors.green : Colors.blue;
    IconData iconData;
    if (status == KeyStatus.revoked) {
      iconData = Icons.key_off;
    } else {
      iconData = presence == KeyPresence.owned ? Icons.vpn_key : Icons.vpn_key_outlined;
    }
    final icon = Icon(iconData, color: color, size: size ?? 20);
    if (presence == KeyPresence.absent) return Opacity(opacity: 0.25, child: icon);
    return icon;
  }
}

class ThrowingKeyIcon extends StatefulWidget {
  final KeyPresence presence;
  final bool animate;
  final KeyType keyType;
  final double iconSize;
  final VoidCallback? onAnimationComplete;

  const ThrowingKeyIcon({
    super.key,
    required this.presence,
    this.animate = false,
    required this.keyType,
    this.iconSize = 48,
    this.onAnimationComplete,
  });

  @override
  State<ThrowingKeyIcon> createState() => _ThrowingKeyIconState();
}

class _ThrowingKeyIconState extends State<ThrowingKeyIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;
  late final Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _offset = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(-8, 0)), weight: 12),
      TweenSequenceItem(tween: Tween(begin: const Offset(-8, 0), end: const Offset(26, -8)), weight: 22),
      TweenSequenceItem(tween: Tween(begin: const Offset(26, -8), end: const Offset(46, -14)), weight: 22),
      TweenSequenceItem(tween: Tween(begin: const Offset(46, -14), end: Offset.zero), weight: 44),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _rot = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3 * pi / 180), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -3 * pi / 180, end: 5 * pi / 180), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 5 * pi / 180, end: 8 * pi / 180), weight: 22),
      TweenSequenceItem(tween: Tween(begin: 8 * pi / 180, end: 0.0), weight: 44),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onAnimationComplete?.call();
    });
  }

  @override
  void didUpdateWidget(ThrowingKeyIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool shouldAnimate = widget.animate && !oldWidget.animate;
    final bool justArrived =
        oldWidget.presence == KeyPresence.absent && widget.presence != KeyPresence.absent;
    if (shouldAnimate || justArrived) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.translate(
        offset: _offset.value,
        child: Transform.rotate(angle: _rot.value, child: child),
      ),
      child: KeyIcon(type: widget.keyType, presence: widget.presence, size: widget.iconSize),
    );
  }
}
