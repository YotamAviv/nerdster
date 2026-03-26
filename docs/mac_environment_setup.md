# Mac Environment Setup Notes

These are the fixes needed after running `flutter upgrade` on a Mac for the first time,
or after merging onto a Mac that hasn't been set up yet.

## 1. Android SDK PATH

`sdkmanager` is installed but not on PATH. Add to `~/.zshrc`:

```bash
# Android SDK
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

Then `source ~/.zshrc`.

## 2. CocoaPods Spec Repo Out of Date

After a Flutter upgrade, the CocoaPods specs repo may be stale:

```bash
pod repo update
```

If the Podfile.lock has a pinned Firebase version that no longer matches what plugins require,
run from the `ios/` directory:

```bash
cd ios && pod update Firebase/Firestore
```

## 3. cloud_firestore_platform_interface Version Pin

After `flutter pub get` on Mac, `cloud_firestore_platform_interface` may resolve to `7.1.0`
which breaks `cloud_firestore 6.1.3`'s own internal code (type signature change in the
delegate API for `Transaction.update` and `WriteBatch.update`).

**Symptom:**
```
cloud_firestore-6.1.3/lib/src/transaction.dart:75: Error: The argument type
'Map<String, dynamic>' can't be assigned to the parameter type 'Map<FieldPath, dynamic>'.
```

**Fix:** pin in `pubspec.yaml`:

```yaml
dependency_overrides:
  cloud_firestore_platform_interface: 7.0.7
```

This should be removed once `cloud_firestore` and `fake_cloud_firestore` release versions
compatible with `cloud_firestore_platform_interface 7.1.0+`.

## 4. flutter doctor Android Warning

```
✗ Flutter requires Android SDK 36 and the Android BuildTools 28.0.3
```

Run after fixing PATH (step 1):

```bash
sdkmanager "platforms;android-36" "build-tools;28.0.3"
flutter doctor --android-licenses
```

---

## Branch State (updated 2026-03-25)

**Branch:** `iosmagic` in `nerdster14` repo. This is the iOS-focused branch merging earlier
work from `ios`, `magic`, and `iphone_bootstrap` (all confirmed merged at commit `4d9dbe5`).

**Merged from `main`:** 2026-03-25. The 4 main commits brought in:
- `cc62da3` — *erroneously* pinned `cloud_firestore_platform_interface` to `7.1.0` on main
  (mistake: 7.1.0 breaks `cloud_firestore 6.1.3` on Mac; see §3 above). This pin has since
  been removed from main entirely.
- `b58fcfe` — sign-in dialog safety net, identity link fix, copy button, KeyStore timeout
- `bc37a77`, `e8c5548` — misc fixes, version 1.1.9+164

**Merge conflict resolution:**
- `pubspec.yaml` version: took main's `1.1.9+164`
- `dependency_overrides`: kept `cloud_firestore_platform_interface: 7.0.7` (correct for iOS/Mac)
- `lib/main.dart`: kept iosmagic's explanatory comment in the KeyStore catch block

**Next steps on Mac:**
1. `git pull` on `iosmagic` branch (or push from Linux first — local is 1 commit ahead of origin)
2. `flutter pub get`
3. If CocoaPods issues: `pod repo update` then `cd ios && pod update Firebase/Firestore`
4. Build and test on device/TestFlight
