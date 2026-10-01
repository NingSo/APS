#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p ios/build
stage="${1:-all}"
prepare() {
  bash ios/bootstrap.sh
  xcodebuild -version
  xcrun simctl list devices available --json > ios/build/devices.json
  export IOS_SIMULATOR_SDK="$(xcrun --sdk iphonesimulator --show-sdk-version)"
  python3 - <<'PY'
import json, os, re
from pathlib import Path
j=json.loads(Path('ios/build/devices.json').read_text())
sdk=tuple(map(int,os.environ['IOS_SIMULATOR_SDK'].split('.')[:2]))
candidates=[]
for runtime, devices in j['devices'].items():
    match=re.search(r'iOS-(\d+)-(\d+)',runtime)
    if not match:
        continue
    version=tuple(map(int,match.groups()))
    if version > sdk or version < (16,0):
        continue
    for d in devices:
        if d['name'].startswith('iPhone') and d.get('isAvailable'):
            candidates.append((version,d['name'],d['udid']))
if not candidates:
    raise SystemExit('No iPhone simulator compatible with the selected Xcode SDK')
version,name,udid=sorted(candidates,reverse=True)[0]
Path('ios/build/selected-device.json').write_text(json.dumps({'runtime':version,'device':name,'sdk':sdk}))
Path('ios/build/device-id.txt').write_text(udid)
print('Selected simulator:',name,'runtime:',version,'SDK:',sdk)
PY
}
boot() {
  DEVICE="$(cat ios/build/device-id.txt)"
  xcrun simctl boot "$DEVICE" 2>/dev/null || true
  python3 ios/scripts/bounded_run.py 240 xcrun simctl bootstatus "$DEVICE" -b
}
build() {
  python3 ios/scripts/bounded_run.py 540 xcodebuild -project ios/APS.xcodeproj -scheme APS \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/build/DerivedData \
    CODE_SIGNING_ALLOWED=NO build-for-testing 2>&1 | tee ios/build/build.log
}
unit() {
  boot
  python3 ios/scripts/bounded_run.py 300 xcodebuild -project ios/APS.xcodeproj -scheme APS \
    -destination "platform=iOS Simulator,id=$DEVICE" -destination-timeout 60 \
    -derivedDataPath ios/build/DerivedData -resultBundlePath ios/build/Unit.xcresult \
    -parallel-testing-enabled NO -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 60 \
    -only-testing:APSTests CODE_SIGNING_ALLOWED=NO test-without-building 2>&1 | tee ios/build/unit.log
  touch ios/build/unit-passed
}
ui() {
  boot
  xcrun simctl io "$DEVICE" recordVideo ios/build/ui-tests.mov > ios/build/video.log 2>&1 &
  VIDEO_PID=$!
  cleanup_video() {
    kill -INT "$VIDEO_PID" 2>/dev/null || true
    for _ in {1..10}; do
      kill -0 "$VIDEO_PID" 2>/dev/null || break
      sleep 1
    done
    kill -TERM "$VIDEO_PID" 2>/dev/null || true
    wait "$VIDEO_PID" 2>/dev/null || true
  }
  trap cleanup_video EXIT
  python3 ios/scripts/bounded_run.py 720 xcodebuild -project ios/APS.xcodeproj -scheme APS \
    -destination "platform=iOS Simulator,id=$DEVICE" -destination-timeout 60 \
    -derivedDataPath ios/build/DerivedData -resultBundlePath ios/build/UI.xcresult \
    -parallel-testing-enabled NO -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 120 -maximum-test-execution-time-allowance 120 \
    -only-testing:APSUITests CODE_SIGNING_ALLOWED=NO test-without-building 2>&1 | tee ios/build/ui.log
  cleanup_video
  trap - EXIT
  touch ios/build/ui-passed
}
collect() {
  for suite in Unit UI; do
    if [ -d "ios/build/$suite.xcresult" ]; then
      xcrun xcresulttool export attachments --path "ios/build/$suite.xcresult" --output-path "ios/build/screenshots/$suite" || true
      xcrun xcresulttool get test-results summary --path "ios/build/$suite.xcresult" > "ios/build/$suite-summary.json" || true
    fi
  done
  if [ -f ios/build/unit-passed ] && [ -f ios/build/ui-passed ]; then
    ditto -c -k --sequesterRsrc --keepParent \
      ios/build/DerivedData/Build/Products/Debug-iphonesimulator/APS.app ios/build/aps-ios-simulator.zip
  fi
}
case "$stage" in
  prepare) prepare;;
  build) build;;
  unit) unit;;
  ui) ui;;
  collect) collect;;
  all)
    trap collect EXIT
    prepare; build; unit; ui; collect
    trap - EXIT
    ;;
  *) echo "Unknown stage: $stage"; exit 2;;
esac
