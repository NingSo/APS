#!/usr/bin/env python3
"""Offline iOS source/provenance guards. This does not compile or execute Swift."""
import json
import pathlib
import plistlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[2]
# The owner separated the iOS branch from Android before this publication task.
# Compare against that reviewed layout, not the retired mixed-platform tree.
base = 'd0f4ca800563818afd446ef7399a5104c616d574'
changed = subprocess.check_output(['git','diff','--name-only',base,'HEAD'],cwd=root,text=True).splitlines()
unexpected = [p for p in changed if not (p.startswith('ios/') or p == '.github/workflows/ios.yml')]
assert not unexpected, f'Changes outside iOS scope: {unexpected}'
assert not (root/'app').exists() and not (root/'proxycore').exists(), 'Keep Android on main, not the isolated iOS branch'
assert not (root/'ios/Sources').exists(), 'Retired iOS source directory must not remain'
assert not (root/'ios/Tests/APS').exists(), 'Retired iOS tests must not remain'
plistlib.loads((root/'ios/Support/PrivacyInfo.xcprivacy').read_bytes())
for file in (root/'ios').rglob('*.json'):
    json.loads(file.read_text())
production = list((root/'ios/APS').glob('*.swift'))
assert production
all_text = '\n'.join(p.read_text() for p in production)
for forbidden in ['AIza' + '[A-Za-z0-9_-]{30,}', 'ghp_' + '[A-Za-z0-9]{20,}', 'BEGIN ' + '(RSA |EC )?PRIVATE KEY']:
    assert not re.search(forbidden, all_text), 'Possible embedded credential'
assert 'VpnService' not in all_text and 'import NetworkExtension' not in all_text
assert 'UIBackgroundModes' not in (root/'ios/project.yml').read_text()
assert '#if DEBUG && targetEnvironment(simulator)' in (root/'ios/APS/AppStore.swift').read_text()
assert 'TimelineView' in (root/'ios/APS/SignalOrbit.swift').read_text()
assert 'repeating: 1' in (root/'ios/APS/ProxyEngine.swift').read_text()
unit = sum(len(re.findall(r'func test\w+\(', p.read_text())) for p in (root/'ios/Tests').glob('*.swift'))
ui = sum(len(re.findall(r'func test\w+\(', p.read_text())) for p in (root/'ios/UITests').glob('*.swift'))
print(json.dumps({'static_checks':'passed','scope_baseline':base,'android_absent_from_ios_branch':True,'retired_ios_removed':True,
                  'production_swift_files':len(production),'unit_methods_written':unit,'ui_methods_written':ui,
                  'note':'Source checks are not executed tests or visual acceptance.'},indent=2))
