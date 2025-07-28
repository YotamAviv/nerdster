import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:nerdster/content/dialogs/check_signed_in.dart';
import 'package:nerdster/oneofus/jsonish.dart';
import 'package:nerdster/oneofus/ui/alert.dart';
import 'package:nerdster/oneofus/util.dart';
import 'package:nerdster/singletons.dart';

class JustSign {
  static Future<void> sign(BuildContext context) async {
    if (!bb(await checkSignedIn(context))) return;

    Json? x = await showKeyValueDialog(context);
    if (!b(x)) return;
    Json json = {}..addAll(x!);
    json['I'] = signInState.signedInDelegatePublicKeyJson!;
    json = LinkedHashMap()..addAll(Jsonish(json).json); // order
    String signature = await signInState.signer!.sign(json, encoder.convert(json));
    json['signature'] = signature;

    unawaited(alert('Signed!', json, ['Okay'], context));
  }
}

Future<Json?> showKeyValueDialog(BuildContext context) {
  final keyController = TextEditingController(text: 'greeting');
  final valueController = TextEditingController(text: "Hello, Nerd'ster!");
  final formKey = GlobalKey<FormState>();
  String? keyError;

  return showDialog<Json>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: kBorderRadius),
      title: const Text('Just Sign'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: keyController,
              decoration: InputDecoration(
                labelText: 'Key',
                errorText: keyError,
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                final key = value?.trim();
                if (key == null || key.isEmpty) return 'Key is required.';
                if (key == 'I' || key == 'signature') {
                  return 'Key "$key" is reserved.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Value is required.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final form = formKey.currentState!;
            if (form.validate()) {
              final key = keyController.text.trim();
              final value = valueController.text.trim();
              Navigator.of(context).pop({key: value});
            }
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
