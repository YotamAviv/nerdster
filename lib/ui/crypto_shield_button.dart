import 'package:flutter/material.dart';
import 'package:oneofus_common/jsonish.dart' show Json, getToken;
import 'package:oneofus_common/ui/json_display.dart';
import 'package:oneofus_common/ui/json_qr_display.dart';
import 'package:nerdster/logic/interpreter.dart';
import 'package:nerdster/logic/labeler.dart';
import 'package:nerdster/settings/prefs.dart';
import 'package:nerdster/settings/setting_type.dart';

/// Shield icon that shows a JsonDisplay popup on tap and a JsonQrDisplay popup
/// on double-tap. Hidden when showCrypto is false.
class CryptoShieldButton extends StatelessWidget {
  final Json json;
  final Labeler labeler;

  const CryptoShieldButton({super.key, required this.json, required this.labeler});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Setting.get<bool>(SettingType.showCrypto),
      builder: (context, showCrypto, _) {
        if (!showCrypto) return const SizedBox.shrink();
        return Builder(builder: (ctx) {
          Offset tapPosition = Offset.zero;
          return GestureDetector(
            onTapDown: (d) => tapPosition = d.globalPosition,
            onDoubleTap: () {
              final screenSize = MediaQuery.of(ctx).size;
              const qrSize = 250.0;
              const qrH = 375.0;
              double left = tapPosition.dx;
              double top = tapPosition.dy;
              if (left + qrSize > screenSize.width) left = tapPosition.dx - qrSize;
              if (top + qrH > screenSize.height) top = tapPosition.dy - qrH;
              if (left < 0) left = 0;
              if (top < 0) top = 0;
              showGeneralDialog<void>(
                context: ctx,
                barrierDismissible: true,
                barrierLabel: '',
                barrierColor: Colors.black12,
                transitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: top,
                      child: Material(
                        elevation: 12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: SizedBox(
                          width: qrSize,
                          height: qrH,
                          child: JsonQrDisplay(getToken(json)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            onTap: () {
              final screenSize = MediaQuery.of(ctx).size;
              final dialogW = (screenSize.width - 16).clamp(0.0, 420.0);
              final dialogH = (screenSize.height - 16).clamp(0.0, 390.0);
              double left = tapPosition.dx;
              double top = tapPosition.dy;
              if (left + dialogW > screenSize.width) left = tapPosition.dx - dialogW;
              if (top + dialogH > screenSize.height) top = tapPosition.dy - dialogH;
              if (left < 0) left = 0;
              if (top < 0) top = 0;
              showGeneralDialog<void>(
                context: ctx,
                barrierDismissible: true,
                barrierLabel: '',
                barrierColor: Colors.black12,
                transitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: top,
                      child: Material(
                        elevation: 12,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: dialogW,
                            height: dialogH,
                            child: JsonDisplay(json, interpreter: NerdsterInterpreter(labeler)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.verified_user_outlined, size: 16, color: Colors.blue),
            ),
          );
        });
      },
    );
  }
}
