import 'package:flutter/material.dart';
import 'package:nerdster/ui/sign_in_widget.dart';

class SignInScreen extends StatelessWidget {
  final VoidCallback? onDismiss;
  const SignInScreen({this.onDismiss, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: SignInDialog(onDismiss: onDismiss),
        ),
      ),
    );
  }
}
