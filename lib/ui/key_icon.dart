import 'package:flutter/material.dart';

enum KeyType {
  identity,
  delegate,
}

enum KeyStatus {
  active,
  revoked, // or replaced
}

class KeyIcon extends StatelessWidget {
  final KeyType type;
  final KeyStatus status;
  final bool isOwned;
  final double? size;

  const KeyIcon({
    super.key,
    required this.type,
    this.status = KeyStatus.active,
    this.isOwned = false,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    assert(!(type == KeyType.identity && isOwned),
        "The Nerdster never has the user's private identity key.");

    // Color
    final Color color = type == KeyType.identity ? Colors.green : Colors.blue;

    // Icon Data
    // Status: active vs revoked
    // Ownership: filled vs outlined
    //
    // Note: Flutter Material Icons naming convention:
    // Filled: Icons.vpn_key
    // Outlined: Icons.vpn_key_outlined
    // Off/Revoked: Icons.key_off (usually filled)

    IconData iconData;

    if (status == KeyStatus.revoked) {
      // We don't have a specific outlined key_off in standard set easily accessible
      // without looking up specific platform impls or using custom icons.
      // Icons.key_off is generally filled.
      // For now, we will use key_off for revoked regardless of ownership,
      // or maybe opacity/color to distinguish?
      // Let's stick to the prompt: "icon has cross through".

      // If we want to strictly follow "Outline for others", we might need
      // Icons.key_off_outlined (doesn't exist in standard stable usually).
      // Let's use Icons.key_off.
      iconData = Icons.key_off;
    } else {
      // Active
      if (isOwned) {
        iconData = Icons.vpn_key; // Filled
      } else {
        iconData = Icons.vpn_key_outlined; // Outline
      }
    }

    return Icon(
      iconData,
      color: color,
      size: size ?? 20, // Default small-ish for inline use
    );
  }
}
