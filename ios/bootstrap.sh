#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo 'Install XcodeGen with: brew install xcodegen'; exit 1; }
swift ios/scripts/make_icon.swift ios/Support/Assets.xcassets/AppIcon.appiconset/AppIcon.png
xcodegen generate --spec ios/project.yml
