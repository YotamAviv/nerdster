import 'package:flutter/material.dart';

/// Key icon display convention used across both the Nerdster and ONE-OF-US.NET apps:
///
/// Color:
///   - Green  = identity key (the user's ONE-OF-US.NET identity)
///   - Blue   = delegate key (a Nerdster-specific signing key)
///
/// Presence (KeyPresence enum):
///   - owned   (Icons.vpn_key, filled)               = we hold the private key pair
///   - known   (Icons.vpn_key_outlined)               = we have the public key only
///   - absent  (Icons.vpn_key_outlined, 25% opacity)  = we don't have the key at all
///
/// Note: the Nerdster app never holds the user's private identity key (that lives in the
/// ONE-OF-US.NET app). Therefore identity keys are always displayed as 'known'.

enum KeyType {
  identity,
  delegate,
}

enum KeyStatus {
  active,
  revoked, // or replaced
}

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

    if (presence == KeyPresence.absent) {
      return Opacity(opacity: 0.25, child: icon);
    }
    return icon;
  }
}
