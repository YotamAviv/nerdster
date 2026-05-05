# Android App Links — Investigation Notes (2026-03-27)

## Summary

### Nerdster (`org.nerdster.app` → `nerdster.org`) ✅ FIXED

**Changes made (committed and pushed on `main`, build 1.1.9+166):**
- `android/app/src/main/AndroidManifest.xml`: Added `autoVerify="true"` intent filter for `https://nerdster.org` — it was completely absent.
- `web/.well-known/assetlinks.json`: Added `org.nerdster.app` entry with Google Play signing key `7B:81:42:C6:EA:F7:AA:56:EC:40:2C:0B:F3:CA:70:9C:A6:13:32:89:A2:18:DF:19:FC:45:7C:1C:6C:ED:6C:D5`
- `pubspec.yaml`: 1.1.9+166

**Status: ✅ LIVE and working.** Build 1.1.9+166 includes the manifest change. Confirmed via adb `nerdster.org: verified`.

---

### ONE-OF-US.NET (`net.oneofus.app` → `one-of-us.net`) ❌ NOT WORKING

> **User note: To my knowledge this has never worked on Android without explicitly using `adb set-app-links` or manually changing phone settings.**

Domain verification shows `one-of-us.net: 1024` (= `STATE_NO_RESPONSE`) on every fresh install. This is regardless of assetlinks.json content.

#### What's already in place (correct):
- `oneofusv22/android/app/src/main/AndroidManifest.xml`: `autoVerify="true"` intent filters for `/sign-in` and `/vouch` paths — already present.
- `web/.well-known/assetlinks.json`: currently deployed to `one-of-us.net` with two fingerprints (see below).
- Content-Type: served as `application/json` ✅
- No HTTP redirects ✅
- Google DAL `statements:list` API shows both fingerprints ✅
- App Links work on device generally (Instagram verified and opens correctly) ✅

#### Signing keys found for `net.oneofus.app`:
| Source | Fingerprint |
|---|---|
| Play Console App Signing key | `10:C5:01:B8:8B:45:A6:5A:0A:2A:98:D3:A6:65:F5:F5:79:1B:01:DD:A8:8B:EF:B0:B1:1F:46:4D:88:32:FA:E8` |
| Play Console recommended assetlinks.json (first) | `8E:96:86:02:EB:56:C2:B7:B8:6B:C8:96:0A:47:2B:86:BF:07:57:88:41:64:94:5B:F4:19:26:E8:43:89:E1:0E` |
| Play Console Upload key | `00:5A:3E:91:C0:1B:C7:B9:41:5C:AA:87:D3:CE:12:13:EE:AE:D6:0B:8B:84:AE:05:01:23:F8:CF:61:88:D5:90` |
| adb installed app signature | `10:C5:01:...` (matches Play signing key) |

The app uses APK v3 signing (key rotation): `past signatures: [a6a808e1, 333020c3]` where `333020c3` is current.

#### Current `assetlinks.json` state (NOT committed, deployed to one-of-us.net only):
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "net.oneofus.app",
      "sha256_cert_fingerprints": [
        "8E:96:86:02:EB:56:C2:B7:B8:6B:C8:96:0A:47:2B:86:BF:07:57:88:41:64:94:5B:F4:19:26:E8:43:89:E1:0E",
        "10:C5:01:B8:8B:45:A6:5A:0A:2A:98:D3:A6:65:F5:F5:79:1B:01:DD:A8:8B:EF:B0:B1:1F:46:4D:88:32:FA:E8"
      ]
    }
  }
]
```

> **⚠️ Note:** The local `web/.well-known/assetlinks.json` currently only has the oneofus entries above. It is missing the original `net.oneofus.app` entries (there were 4 legacy ones) AND the `org.nerdster.app` entry. Running `stage_nerdster.sh deploy` from this state would break nerdster.org's App Links. Restore or rebuild before deploying to nerdster.

#### Failed experiments:
1. **4 separate single-fingerprint entries** — original format, all `net.oneofus.app` with different certs → `1024`
2. **Single entry with only `10:C5:01:...`** → `1024`
3. **Two entries: `8E:96:86:...` + `10:C5:01:...`** (Play Console recommendation) → `1024`
4. **`pm verify-app-links --re-verify`** — triggers re-check; still `1024` after 60+ seconds
5. **`pm reset-app-links`** — does not clear Disabled/1024 state
6. **Tested 2 devices, 2 different Google accounts** — both fail identically

#### Diagnostics:
- `adb shell pm get-app-links --user 0 net.oneofus.app`:
  - `Signatures: [10:C5:01:...]`
  - `Domain verification state: one-of-us.net: 1024`
  - `Selection state: Disabled: one-of-us.net`
- Google DAL `statements:list` → returns both fingerprints ✅
- Google DAL `statements:check` → returns HTTP 404 for BOTH fingerprints ❌
- Logcat (`AppLinksAsyncVerifierV2`) → verification completes in ~300ms, all values REDACTED, no errors

#### Working workaround (device-specific only):
```bash
adb shell pm set-app-links --package net.oneofus.app 2 one-of-us.net
```
This force-approves the domain for the app on that specific device. Not a real fix.

> **⛔ AI: NEVER run this command. The human is the boss. This masks the real problem and creates a false sense that the feature works.**

#### Hypotheses not yet ruled out:
- Google's internal App Links verification backend has a different record for `net.oneofus.app` than what the Play Console shows
- APK v3 signing key rotation might be interfering with domain verification
- Google's backend cache needs >24 hours to update for this app

#### Next steps:
1. Wait 24+ hours, test fresh install again on both devices
2. Check the Play Console → App integrity → "Digital Asset Links" section for any native domain linking tool
3. If still broken, consider contacting Google Play developer support

---

## vouch.html note

The `https://one-of-us.net/...` link displayed on `vouch.html` is useless for opening the app from within Chrome. Android App Links only trigger from outside the browser (e.g., email, Messages). From within Chrome, the `keymeid://` scheme is the correct approach. The https link on vouch.html will never open the app.
