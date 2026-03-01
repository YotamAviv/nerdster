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

- [ ] Attempt a build for Android/iOS and catalog compile errors.
- [ ] Fix any web-only imports (e.g. `dart:js_interop`, `package:web`) that are not already
      guarded by the `dart.library.io` / `kIsWeb` pattern.
- [ ] Verify `flutter_secure_storage` works correctly on device for key persistence.
- [ ] Verify sign-in flow works end-to-end on phone (URL scheme / App Link via identity app).
- [ ] Verify statement loading works (cloud function fetch).

### Phase 2 — Phone-Specific Features

Goal: leverage phone capabilities where beneficial.

- [ ] `magicPaste` (URL metadata): phone can fetch URLs directly via the `http` package,
      bypassing the cloud function. Evaluate whether this is worthwhile.

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
