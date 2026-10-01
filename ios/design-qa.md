# iOS design QA

- source visual truth: approved Android sources and docs/APS-SIGNAL at c2dd0a2616bbcf0b7f582c13c2d40316bba7dbfd
- implementation screenshots: pending native workflow XCTest attachments
- viewport: actual iPhone simulator safe-area viewport; device/density recorded by Xcode
- normalization: not performed without rendered native output
- state: stopped, running, failed, no-address, configuration, sharing
- full-view comparison evidence: pending
- focused comparison evidence: pending (orbit, typography, QR/card geometry, sheets)
- comparison history: no rendered comparison completed during source authoring
- known intentional differences: iOS native system chrome and sheet gestures; foreground-only lifecycle; system Dynamic Type
- remaining findings: native screenshot comparison and motion review required; no pixel-match percentage or performance result is claimed
- final result: blocked
