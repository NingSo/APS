# Android stable releases

The owner has accepted the Android functionality. Android 1.0.0 is distributed as `APS-Android-1.0.0.apk`, tag `android-v1.0.0`, package `com.ningso.aps`, versionCode 2, minimum Android 8.0. It is a non-debuggable Release build, not a renamed debug APK. The old `android-v0.1.0-preview.1` Release is removed only after the new stable APK is published and its digest verified; its historical Git tag is retained. The iOS branch and release are unaffected.

`Publish Android stable APK` checks source integrity, runs release-validation tests, compiles/tests/lints the Release variant, signs the APK, checks package/version/signature/alignment, uploads a draft and then publishes it as Latest. A main-branch commit must explicitly contain `[release-android]`, or use workflow_dispatch. Update `app/build.gradle.kts` and `.github/releases/android.json` together and increment versionCode for future updates. Existing published assets are never overwritten.

## Signing identity

The first stable release can initialize an RSA-4096 signing identity only when `bootstrap_signer` is true, the tag is `android-v1.0.0`, no signing fingerprint is pinned, and that release does not exist. The keystore/passwords are encrypted with OpenSSL CMS AES-256-GCM to the owner's recovery certificate before publication. Only ciphertext is uploaded to the recovery Actions artifact; private keys/passwords never enter Git or public Release assets. The recovery private key is delivered privately to the owner. The public certificate is not an APK signing key.

After publication, disable bootstrap and pin the release certificate fingerprint in `.github/releases/android-signing.sha256`. The owner must keep the decrypted signing backup and configure these Actions secrets for subsequent versions: `APS_ANDROID_KEYSTORE_B64`, `APS_ANDROID_STORE_PASSWORD`, `APS_ANDROID_KEY_ALIAS`, `APS_ANDROID_KEY_PASSWORD`. Never generate a different key to work around missing credentials. The connected integration cannot write repository secrets, so restoring these values is an owner-side step.

The stable application can coexist with `com.ningso.aps.debug`; it does not migrate that app's data. Do not run both apps on identical listening ports. Future stable updates use the same signing identity. Download the APK asset, not Source code ZIP/TAR.
