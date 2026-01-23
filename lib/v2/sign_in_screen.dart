import 'package:flutter/material.dart';
import 'package:nerdster/v2/sign_in_widget.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-use the existing dialog structure but presented as a full screen body
    return const Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: SignInDialog(),
        ),
      ),
    );
  }
}
