# iOS packages and distribution

The ios branch remains an independent iOS project. Do not reintroduce Android sources from main.

A commit message containing `[release-ios]`, or a manual iOS workflow dispatch, enables publication only after native compilation, unit/proxy tests and UI tests all succeed. A separate job builds a Release app with the iPhoneOS SDK, packages Payload/APS.app as an IPA and uploads it to GitHub Releases. The tag comes from ios/release.json. Use a new preview number for another publication; existing tags/assets are never overwritten. Ordinary development commits run tests without creating releases.

The first asset is APS-iOS-1.0.0-unsigned.ipa. This is an arm64 physical-device IPA, not a simulator ZIP. **It lacks Apple distribution signing and cannot be installed by tapping the download.** Users need their own signing/provisioning or can build and run on a connected device in Xcode using their own Team. This is not a TestFlight or App Store publication.

Distribution requirements must remain explicit: APKs install on Android; unsigned IPAs need re-signing; Ad Hoc IPAs require registered devices in the matching profile; TestFlight is preferable for ordinary iPhone testers. Apple Distribution private keys and provisioning assets belong only in secure CI secrets, never public source or assets. No private keys were read or published and no shared enterprise certificate was configured.

Publication checks platform, arm64 architecture, bundle identity, version, executable and ZIP integrity; simulator and test bundles are rejected. SHA256SUMS, provenance and installation instructions accompany the IPA. Simulator tests and device-SDK compilation do not establish physical-device acceptance.

The scope guard now uses the existing iOS-only d0f4ca8 baseline, retaining isolation checks while fixing the obsolete mixed-platform comparison. Application UI, proxy implementation and test assertions are unchanged.
