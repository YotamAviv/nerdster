# Nerdster Mobile Deep Links

## What

When a user taps a `https://nerdster.org/...` link on their phone, Android/iOS opens the
Nerdster app directly instead of a browser.

---

## Code changes (already done)

- **`android/app/src/main/AndroidManifest.xml`**: App Link intent filter for `nerdster.org` (`autoVerify="true"`)
- **`ios/Runner/Runner.entitlements`**: Associated Domains for `applinks:nerdster.org` and `applinks:www.nerdster.org`
- **`ios/Runner/Info.plist`**: `FlutterDeepLinkingEnabled = true`
- **`web/.well-known/assetlinks.json`**: Added `org.nerdster.app` entry (SHA-256 fingerprint from `googlekeystore.jks / nerdsterandroidkey`)
- **`web/.well-known/apple-app-site-association`**: Added `PG2Q5QYA2W.org.nerdster.app` entry with `paths: ["*"]`

Deploy with: `bash bin/stage_nerdster.sh deploy`

---

## Steps you must do

### 1. Register entitlements in Xcode (iOS, Mac required)

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **Runner** target → **Signing & Capabilities**.
3. Click **+ Capability** → **Associated Domains**.
4. Verify `applinks:nerdster.org` and `applinks:www.nerdster.org` are listed.

Or edit `ios/Runner.xcodeproj/project.pbxproj` directly:
```
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```
(Same pattern as oneofusv22.)

### 2. Add Flutter link handler in Dart (optional for now)

Currently the app opens but doesn't route anywhere specific on incoming links.
When you're ready, add `app_links` to `pubspec.yaml` and wire it up in `main.dart`.

### 3. Verify after deploy

**Android:**
```bash
adb shell pm get-app-links org.nerdster.app
# Should show STATE_APPROVED for nerdster.org
```

**iOS:** Use [Apple's AASA validator](https://branch.io/resources/universal-links/).

---

## Status

| Step | Who | Done? |
|------|-----|-------|
| AndroidManifest.xml intent filter | AI | ✅ |
| iOS Runner.entitlements | AI | ✅ |
| iOS Info.plist FlutterDeepLinkingEnabled | AI | ✅ |
| `web/.well-known/assetlinks.json` | AI | ✅ |
| `web/.well-known/apple-app-site-association` | AI | ✅ |
| Deploy (`bash bin/stage_nerdster.sh deploy`) | You | ✅ |
| iOS: register entitlements in `project.pbxproj` | AI | ✅ |
| Dart: app_links link handler | AI | ✅ |
| Verify App Links (Play Store) | You | ⬜ after deploy |
| Verify Universal Links (App Store) | You | ⬜ after deploy |
