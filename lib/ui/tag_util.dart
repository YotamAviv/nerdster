import 'package:flutter/material.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/models/equivalence_statement.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';
import 'package:nerdster/singletons.dart';
import 'package:nerdster_common/ui/json_interpreter.dart';
import 'package:oneofus_common/jsonish.dart' show Json;
import 'package:oneofus_common/ui/json_display.dart';

class DontEquateButton extends StatelessWidget {
  final VoidCallback onPressed;
  const DontEquateButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text('≠',
            style: TextStyle(
                fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class DontRelateButton extends StatelessWidget {
  final VoidCallback onPressed;
  const DontRelateButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text('!~',
            style: TextStyle(
                fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String message;
  final void Function(bool) onResult;
  const ConfirmDialog({super.key, required this.message, required this.onResult});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      content: Text(message, style: const TextStyle(fontSize: 13)),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              textStyle: const TextStyle(fontSize: 13)),
          onPressed: () => onResult(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              textStyle: const TextStyle(fontSize: 13)),
          onPressed: () => onResult(true),
          child: const Text('Ok'),
        ),
      ],
    );
  }
}

class GroupShieldButton extends StatelessWidget {
  final VoidCallback onTap;
  const GroupShieldButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!Setting.get<bool>(SettingType.showCrypto).value) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.verified_user_outlined, size: 14, color: Colors.blue),
      ),
    );
  }
}

class StatementShieldButton extends StatelessWidget {
  final Json? json;
  final void Function(Offset tapPosition) onShowJson;
  const StatementShieldButton({super.key, required this.json, required this.onShowJson});

  @override
  Widget build(BuildContext context) {
    if (json == null) return const SizedBox.shrink();
    Offset tapPos = Offset.zero;
    return GestureDetector(
      onTapDown: (d) => tapPos = d.globalPosition,
      onTap: () => onShowJson(tapPos),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.verified_user_outlined, size: 14, color: Colors.blue),
      ),
    );
  }
}

class TagProvenanceDialog extends StatelessWidget {
  final String canonical;
  final List<EquivalenceStatement> statements;
  final void Function(Json? json, Labeler labeler, Offset tapPosition)? onShowJson;
  final String? myDelegateToken;
  final void Function(EquivalenceStatement s)? onClear;

  const TagProvenanceDialog({
    super.key,
    required this.canonical,
    required this.statements,
    this.onShowJson,
    this.myDelegateToken,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final labeler = globalLabeler.value;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('"$canonical" equate and relate statements',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: statements.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final s = statements[i];
                  final label = labeler.getLabel(s.iToken);
                  final isMyStatement =
                      myDelegateToken != null && s.iToken == myDelegateToken;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 13)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: s.equivalent),
                              TextSpan(
                                text: s.isRelate
                                    ? (s.isNotRelate ? '  !~  ' : '  ~  ')
                                    : (s.not ? '  ≠  ' : '  →  '),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: s.isRelate
                                      ? (s.isNotRelate ? Colors.red : Colors.green)
                                      : (s.not ? Colors.red : Colors.green),
                                ),
                              ),
                              TextSpan(text: s.canonical),
                            ]),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onShowJson != null)
                          StatementShieldButton(
                            json: s.json,
                            onShowJson: (pos) => onShowJson!(s.json, labeler, pos),
                          ),
                        if (isMyStatement && onClear != null)
                          GestureDetector(
                            onTap: () => onClear!(s),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.close, size: 14, color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Opens a JSON display overlay anchored near [tapPosition].
/// The returned [OverlayEntry] is inserted into [overlay]; the caller is
/// responsible for removing it when appropriate.
OverlayEntry openJsonOverlay({
  required BuildContext context,
  required Json json,
  required Labeler labeler,
  required Offset tapPosition,
  required VoidCallback onDismiss,
}) {
  final size = MediaQuery.of(context).size;
  final dw = (size.width - 16).clamp(0.0, 420.0);
  final dh = (size.height - 16).clamp(0.0, 390.0);
  double left = tapPosition.dx;
  double top = tapPosition.dy;
  if (left + dw > size.width) left = tapPosition.dx - dw;
  if (top + dh > size.height) top = tapPosition.dy - dh;
  if (left < 0) left = 0;
  if (top < 0) top = 0;

  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
        ),
      ),
      Positioned(
        left: left,
        top: top,
        child: Material(
          elevation: 12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: dw,
              height: dh,
              child: JsonDisplay(json, interpreter: JsonInterpreter(labeler)),
            ),
          ),
        ),
      ),
    ]);
  });
  return entry;
}
