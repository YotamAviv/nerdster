# Nerdster Phone App Plan

The Nerdster is a Flutter app that already targets web (production) and Android/iOS (experimental).
This document describes the plan for bringing the phone app to a usable state, the phases of work,
and known deferred items.

## Background

The codebase is a single Flutter project that compiles to both web and native (Android/iOS).

The webapp is in production and must be maintained.
The new phone app can start out as experimental.

There is no separate repo or
long-lived Git branch; platform-specific behavior is gated with `kIsWeb` and
`defaultTargetPlatform` guards in the Dart code, keeping a single history in `main`.

## Sign-In on Phone

Sign-in on the Nerdster phone app relies on the **ONE-OF-US.NET phone app** being installed
on the same device. The Nerdster phone app presents sign-in parameters (via a URL scheme or
universal/app link) that the identity app processes and returns the keys.

The `sign_in_widget.dart` already handles this correctly:
- **Android**: URL scheme (`keymeid://`) is recommended; App Link is secondary.
- **iOS**: App Link (`https://one-of-us.net/sign-in?...`) is recommended; URL scheme is secondary.
- **QR Code**: Listed last on phone. On desktop/web it is the primary method (scan with phone's identity app).

It does not make sense for the Nerdster phone app to show a sign-in QR code for the user to
scan with the same phone. QR sign-in is a cross-device flow (desktop Nerdster ↔ phone identity app).

## Statement Fetching

The phone app continues to use the `export` cloud function (`export.nerdster.org`) for reading
statements, exactly as the webapp does. The cloud function performs server-side work (distinct,
notarization verification, revocation) that reduces bandwidth and processing on the client.
There is no CORS restriction on native phone apps, but no change to `SourceFactory` is needed
for this reason alone.

## Architecture (No Change)

- `SourceFactory` — no change; phone uses `CloudFunctionsSource` in prod, same as web.
- `message_handler.dart` — web-only JavaScript bridge, already conditionally excluded on native
  via `stub_message_handler.dart`. No change needed.
- `firebase_options.dart` — `DefaultFirebaseOptions.currentPlatform` already handles per-platform
  Firebase configuration.

## Phases

### Phase 1 — Compile and Run (Current Focus)

Goal: get the phone app to build and run on Android/iOS without crashes.

- [x] Attempt a build for Android/iOS and catalog compile errors.
      - Added Android platform via `flutter create --platforms=android`.
      - Fixed `minSdk` to 23 (required by `cloud_functions`) and `ndkVersion` to 27.0.12077973.
      - Deleted dead code: `lib/ui/pop_state_web.dart` (unreferenced, web-only).
- [x] Fix any web-only imports (e.g. `dart:js_interop`, `package:web`) that are not already
      guarded by the `dart.library.io` / `kIsWeb` pattern. (All clear.)
- [ ] Verify `flutter_secure_storage` works correctly on device for key persistence.
- [ ] Verify sign-in flow works end-to-end on phone (URL scheme / App Link via identity app).
- [x] Verify statement loading works (cloud function fetch).
      - Integration tests (`basic_test.dart`, `ui_test.dart`) pass on Android emulator.
      - Fixed integration tests to use `10.0.2.2` instead of `localhost` when running on
        Android (Android emulator routes `10.0.2.2` to the host machine).

### Phase 2 — Phone-Specific Features

Goal: leverage phone capabilities where beneficial.

- [x] **URL metadata (`magicPaste`)**: On native, fetches URLs directly via `http` package,
      bypassing the `magicPaste` cloud function. On web, cloud function is unchanged.
      Logic ported from `functions/url_metadata_parser.js`: YouTube oEmbed → JSON-LD →
      OpenGraph → title fallback → content-type inference.
      Integration test (`magic_paste_test.dart`) on Android: **3/4 required pass**.
      IMDb fails because Amazon's bot protection blocks direct HTTP from emulator/phone IPs
      (GCP IPs used by the cloud function have better reputation). On web, the cloud function
      continues to handle IMDb correctly.
- [/] **Image fetching (`fetchImages`)**: On native, fetch images directly via HTTP,
      bypassing the `fetchImages` cloud function. Sources (all free, no API keys):
      YouTube thumbnails, HTML `og:image`, OpenLibrary (books), Wikipedia.
      OMDB/TMDB are skipped — they require API keys that are not configured (see `TODO.md`).
- [x] **App icon**: `assets/images/nerd.png` resized to all Android mipmap densities
      (mdpi 48px → xxxhdpi 192px) and placed in `android/app/src/main/res/mipmap-*/`.

### Phase 3 — Google Play Store

#### Signing setup (one-time)

The existing keystore is `~/googlekeystore.jks` (alias `oneofusandroidkey2` = ONE-OF-US.NET).
Nerdster needs its own alias in the same file:

```bash
keytool -genkey -alias nerdsterandroidkey -keystore ~/googlekeystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then add a signing block to `android/app/build.gradle.kts`:

```kotlin
val keystoreProperties = java.util.Properties().apply {
    load(rootProject.file("android/key.properties").inputStream())
}

android {
    signingConfigs {
        create("release") {
            keyAlias     = keystoreProperties["keyAlias"] as String
            keyPassword  = keystoreProperties["keyPassword"] as String
            storeFile    = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("release") }
    }
}
```

Create `android/key.properties` (gitignored — never commit this):

```
storeFile=/home/aviv/googlekeystore.jks
storePassword=<your-keystore-password>
keyAlias=nerdsterandroidkey
keyPassword=<your-key-password>
```

Ensure `android/key.properties` is in `android/.gitignore`.

#### Build and upload

```bash
flutter build appbundle          # produces build/app/outputs/bundle/release/app-release.aab
```

Upload `app-release.aab` to Play Console → create new app → Internal Testing → upload AAB.
Play Console will prompt to opt in to Google Play App Signing (recommended — keeps the
distribution key separate from the upload key).

#### Store listing

- [ ] Create screenshots from the Simpsons demo running on the emulator:
      run demo → sign in as Lisa → screenshot content feed, adding an item, etc.
- [ ] Write short description (~80 chars) and full description.
- [ ] Confirm app icon (512×512 PNG) looks right at Play Store scale.
- [ ] Privacy policy URL (required by Google).



## Deferred Items

### Shareable Link Support

The Nerdster webapp has a "Share, bookmark, or embed" feature (in the Etc bar) that generates a
URL encoding the user's current PoV and settings (follow context, tags, sort, type, etc.) as
query parameters. On the web, opening such a link loads the webapp with those settings applied
(handled in `defaultSignIn()` via `Uri.base.queryParameters`).

It would be desirable for these links to also launch the phone app with the settings correctly
applied. This would require:
1. Android: App Links / intent filters that intercept `nerdster.org` URLs and open the app.
2. iOS: Universal Links that do the same.
3. Parsing the settings from the deep link URL and applying them at startup.

For now, shareable links open the webapp only. This is acceptable. Implementing deep link
routing for settings is deferred.

### `defaultSignIn()` on Mobile

`defaultSignIn()` reads `Uri.base.queryParameters` to handle the POV query parameter on web.
On mobile, `Uri.base` is not meaningful. Currently harmless (returns empty, falls through to
key store). Full deep-link-based startup sign-in is deferred (see Shareable Link Support above).
