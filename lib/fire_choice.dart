enum FireChoice {
  fake,
  emulator,
  prod;
}

// Default set from --dart-define=fire=emulator (mobile equivalent of ?fire=emulator on web).
// May be further overwritten by query parameters on web.
FireChoice fireChoice = const String.fromEnvironment('fire') == 'emulator'
    ? FireChoice.emulator
    : FireChoice.prod;
