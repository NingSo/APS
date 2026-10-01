# Android stable releases

The owner has accepted the Android functionality. Android 1.0.0 is distributed as `APS-Android-1.0.0.apk`, tag `android-v1.0.0`, package `com.ningso.aps`, versionCode 2, minimum Android 8.0. It is a non-debuggable Release build, not a renamed debug APK. The named `android-v0.1.0-preview.1` Release is removed only after its replacement is published and verified. No historical Git tags are deleted by this workflow. The iOS branch and release are unaffected.

`Publish Android stable APK` checks source integrity and release-validation tests, runs the existing debug-variant application/core unit tests, independently lints and compiles the Release variant, signs the APK, verifies its identity/signature/alignment, and publishes it as Latest. A main-branch commit must explicitly contain `[release-android]`, or use workflow_dispatch. Update `app/build.gradle.kts` and `.github/releases/android.json` together and increment versionCode for future updates. Existing published assets are never overwritten.

## Established signing identity

The first stable release initialized a dedicated RSA-4096 signing identity. Its recovery backup was encrypted with OpenSSL CMS AES-256-GCM before upload to an Actions artifact. Private signing keys and passwords were never placed in Git or public Release assets. The owner receives the recovered password-encrypted PKCS12 backup and its separate password privately.

Bootstrap key generation is now disabled. `.github/releases/android-signing.sha256` pins the release certificate fingerprint. To publish future versions, the owner must restore the saved key into these Actions secrets: `APS_ANDROID_KEYSTORE_B64`, `APS_ANDROID_STORE_PASSWORD`, `APS_ANDROID_KEY_ALIAS`, `APS_ANDROID_KEY_PASSWORD`. The private backup includes a local helper which validates both the backup and certificate fingerprint and requires explicit confirmation before setting secrets. The connected integration cannot set these repository secrets; do not regenerate a key to work around missing credentials.

The stable app can coexist with `com.ningso.aps.debug`; it does not migrate that app's settings. Do not run both apps on identical ports. Installing the current APK does not require the private signing backup or secret configuration.
