# Flutter Upgrade Notes: 3.32.8 → 3.41.x

Recorded: 2026-03-18

## Current State
- **Installed**: 3.32.8, stable channel (July 2025)
- **Latest stable**: 3.41.x
- **Crossing**: 3.35, 3.38, 3.41 — three major stable releases

---

## Breaking Changes That Could Affect Nerdster

### 3.35
- `Radio` widget redesigned — check styling if used
- `DropdownButtonFormField.value` → `initialValue` (deprecated)
- `AppBar` color deprecated
- Android: default `abiFilters` now set automatically (likely transparent)

### 3.38 ⚠️
- **`UISceneDelegate` adoption** — Apple now requires UIScene lifecycle for iOS.
  Flutter 3.38 migrates to this. Touches `AppDelegate` and `Info.plist`.
  Flutter may auto-migrate on first `flutter run` after upgrade.
  Migration guide: https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
- Android default page transition changed to `PredictiveBackPageTransitionBuilder` (visual change)

### 3.41
- Linux merged threads (desktop only — irrelevant)
- `FontWeight` now affects variable font weight attribute (cosmetic)
- Material 3 token updates (minor theming shifts)

---

## How to Roll Back

Flutter doesn't have a built-in rollback. Options:

### Git checkout (no fvm)
```bash
cd ~/flutter    # or wherever your Flutter SDK is installed
git checkout 3.32.8
flutter pub get
```

### fvm (cleaner, per-project pinning)
```bash
fvm install 3.32.8
fvm install 3.41.x
fvm use 3.32.8   # pins version for current project
```

---

## Post-Upgrade Checklist
1. `flutter pub get`
2. `flutter analyze` — fix any new deprecation warnings
3. Test on Android (check page transition behavior)
4. Test on iOS (watch for UISceneDelegate migration prompt)
5. Re-run App Store / Play Store build pipeline

---

## References
- [Breaking changes overview](https://docs.flutter.dev/release/breaking-changes)
- [3.35 breaking changes](https://docs.flutter.dev/release/breaking-changes#released-in-flutter-3-35)
- [3.38 breaking changes](https://docs.flutter.dev/release/breaking-changes#released-in-flutter-3-38)
- [3.41 breaking changes](https://docs.flutter.dev/release/breaking-changes#released-in-flutter-3-41)
- [UISceneDelegate migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)
