# Installer publication

Installable Android packages belong in GitHub Releases assets, not only Actions artifacts or source ZIPs.

`Publish installable Android APK` reads `.github/releases/android.json`. It verifies a successful main-branch CI run, source SHA, artifact SHA-256, APK signature and package identity before publishing the exact APK, signature summary, installation notes and SHA256SUMS. The release stays a draft until all assets are uploaded. Existing tags and published assets are never replaced.

The first tag is `android-v0.1.0-preview.1`, sourced from the successful CI of the latest Android code `e289d3c`. Its internal version is `0.1.0-debug`, package ID `com.ningso.aps.debug`, minimum Android 8.0. It is an installable DEBUG-signed preview, not a production-key release. A differently signed existing install cannot be upgraded in place; uninstalling deletes app data, so back up anything needed first.

For subsequent releases, wait for Android CI success and update tag, source_sha, run_id, artifact_name and artifact_sha256 in the manifest on main. The workflow can also be dispatched manually. Stale source, failing CI, expired artifacts and verification mismatches block publication. Production updates require a stable release keystore; never commit signing keys.

The ios branch develops and publishes independently. An iPhone needs a device-SDK IPA and valid signing/distribution conditions. Simulator ZIPs cannot run on iPhone. Unsigned IPAs must be explicitly labelled as requiring re-signing, never as tap-to-install packages.
