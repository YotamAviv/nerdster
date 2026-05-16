# Nerdster Mobile Deep Links

## What

When a user taps a `https://nerdster.org/...` link on their phone, Android/iOS opens the
Nerdster app directly instead of a browser.

---

## Code changes (already done)

- **`android/app/src/main/AndroidManifest.xml`**: App Link intent filter for `nerdster.org` (`autoVerify="true"`)
- **`ios/Runner/Runner.entitlements`**: Associated Domains for `applinks:nerdster.org` and `applinks:www.nerdster.org`
- **`ios/Runner/Info.plist`**: `FlutterDeepLinkingEnabled = false`
- **`web/.well-known/assetlinks.json`**: Added `org.nerdster.app` entry (SHA-256 fingerprint from `googlekeystore.jks / nerdsterandroidkey`)
- **`web/.well-known/apple-app-site-association`**: Added `PG2Q5QYA2W.org.nerdster.app` entry with `components` format

Deploy with: `bash bin/stage_nerdster.sh deploy`

---

## Critical: FlutterDeepLinkingEnabled must be `false`, not just absent

`Info.plist` must contain:

```xml
<key>FlutterDeepLinkingEnabled</key>
<false/>
```

**Do NOT simply remove the key.** Per Flutter's implementation, a missing key is treated
the same as `true`. With `FlutterDeepLinkingEnabled = true` (or absent):

1. Flutter's engine intercepts every Universal Link via `continueUserActivity`.
2. It tries to push the full URL (e.g. `/?identity=...&sort=netLikes&...`) as a named
   route into `MaterialApp`.
3. `MaterialApp` has no named routes defined → navigation fails.
4. Flutter logs: **`"Failed to handle route information in Flutter."`**
5. iOS sees the Universal Link as unhandled and falls back to opening in Safari.
6. Safari shows an "Open" banner → user taps it → app opens again → infinite bounce loop.

Setting `FlutterDeepLinkingEnabled = false` prevents the engine from intercepting links,
leaving `app_links` to handle them exclusively via its native iOS plugin.

This was diagnosed by running `xcrun simctl openurl` on the simulator with the debug build
and observing the log output.

---

## Dart-side link handling (`lib/main.dart`)

Two mechanisms cover both scenarios:

**Cold start** (app launched by tapping a Universal Link):
```dart
final initialLink = await AppLinks().getInitialLinkString();
if (initialLink != null) startupUri = Uri.parse(initialLink);
```

**Foreground** (app already running when a Universal Link is tapped):
```dart
if (!kIsWeb) {
  AppLinks().uriLinkStream.listen((uri) {
    defaultSignIn(params: uri.queryParameters);
  }, onError: (_) {});
}
```

Both call `defaultSignIn` which processes `?identity=`, `?qrSignIn=true`, and Prefs
settings (`?sort=`, `?contentType=`, `?lgtm=`, `?showCrypto=`, etc.).

---

## AASA (`web/.well-known/apple-app-site-association`)

Uses the modern `components` format for `org.nerdster.app` (required for iOS 15.4+
query-parameter matching). Apple CDN and origin server are in sync.

The `{ "/": "/*" }` component entry matches all paths with or without query strings.

---

## Steps you must do

### 1. Register entitlements in Xcode (iOS, Mac required)

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **Runner** target → **Signing & Capabilities**.
3. Click **+ Capability** → **Associated Domains**.
4. Verify `applinks:nerdster.org` and `applinks:www.nerdster.org` are listed.

### 2. Verify after deploy

**Android:**
```bash
adb shell pm get-app-links org.nerdster.app
# Should show STATE_APPROVED for nerdster.org
```

**iOS:** Use [Apple's AASA validator](https://branch.io/resources/universal-links/).

---

## Debugging Universal Links (simulator)

Universal Links can be tested in the iOS simulator without a real device or domain
verification, using `xcrun simctl openurl`.

```bash
# 1. Boot a simulator and run the app in debug mode
xcrun simctl boot <simulator-udid>          # or open Simulator.app and boot manually
flutter run -d <simulator-udid>

# 2. In another terminal, inject a Universal Link tap
xcrun simctl openurl booted "https://nerdster.org/?identity=...&sort=netLikes"
```

The flutter debug output will show exactly what happens:
- `flutter: Query parameters: {...}` — confirms app_links received the URL
- `"Failed to handle route information in Flutter."` — Flutter route interception is
  active (means `FlutterDeepLinkingEnabled` is not properly `false`)
- `flutter: ThrowingKeyIcon: Starting animation!` — sign-in succeeded

> **Note:** `xcrun simctl openurl` bypasses AASA domain verification. It simulates the
> *app receiving* the link, not iOS routing it. For AASA validation, use the
> [Apple AASA validator](https://branch.io/resources/universal-links/).

List available simulator UDIDs:
```bash
xcrun simctl list devices | grep -E "Booted|iPhone"
```

---



- Android uses App Links (`autoVerify="true"` in `AndroidManifest.xml`) — no equivalent
  of `FlutterDeepLinkingEnabled` exists on Android.
- The `uriLinkStream` listener in `main.dart` is guarded by `!kIsWeb` and handles Android
  foreground links identically to iOS.
- The `web/.well-known/assetlinks.json` file handles Android domain verification.
- `flutter_secure_storage` on Android may be invalidated after a PIN/biometric change —
  the `KeyStore.readKeys()` timeout/catch in `main.dart` handles this gracefully.

---

## Status

| Step | Who | Done? |
|------|-----|-------|
| AndroidManifest.xml intent filter | AI | ✅ |
| iOS Runner.entitlements | AI | ✅ |
| iOS Info.plist `FlutterDeepLinkingEnabled = false` | AI | ✅ |
| `web/.well-known/assetlinks.json` | AI | ✅ |
| `web/.well-known/apple-app-site-association` | AI | ✅ |
| Deploy (`bash bin/stage_nerdster.sh deploy`) | You | ✅ |
| iOS: register entitlements in `project.pbxproj` | AI | ✅ |
| Dart: cold-start `getInitialLinkString()` | AI | ✅ |
| Dart: foreground `uriLinkStream` listener | AI | ✅ |
| Verify App Links (Play Store) | You | ⬜ after Android merge |
| Verify Universal Links (iOS) | You | ⬜ build +168 |
