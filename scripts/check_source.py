#!/usr/bin/env python3
"""Offline source/configuration checks, NOT Kotlin compilation or Android testing."""
from __future__ import annotations

import ast
import hashlib
import json
from pathlib import Path
import re
import sys
import tomllib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def check() -> dict:
    failures: list[str] = []
    lock = json.loads((ROOT / 'upstream-lock.json').read_text())
    for name, expected in lock['files'].items():
        path = ROOT / name
        if not path.is_file():
            failures.append(f'Missing upstream source: {name}')
            continue
        data = path.read_bytes()
        actual = hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()
        if actual != expected:
            failures.append(f'Upstream source changed: {name}')
    required = [
        'LICENSE', 'NOTICE', 'README.md', 'README.zh-CN.md',
        'settings.gradle.kts', 'build.gradle.kts', 'app/build.gradle.kts', 'proxycore/build.gradle.kts',
        'gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.properties',
        '.github/workflows/android.yml', '.github/workflows/native-ui.yml',
        'app/src/main/assets/open_source.txt', 'scripts/bootstrap_gradle.py',
    ]
    for name in required:
        if not (ROOT / name).is_file():
            failures.append(f'Missing project file: {name}')
    source_files = [p for p in ROOT.rglob('*') if p.is_file() and '.git' not in p.parts and 'build' not in p.parts and '__pycache__' not in p.parts]
    xml_files = [p for p in source_files if p.suffix == '.xml']
    for path in xml_files:
        try:
            ET.parse(path)
        except ET.ParseError as error:
            failures.append(f'XML: {path.relative_to(ROOT)}: {error}')
    versions = tomllib.loads((ROOT / 'gradle/libs.versions.toml').read_text())
    for section in ('plugins', 'libraries'):
        for name, item in versions[section].items():
            version = item.get('version')
            if isinstance(version, dict) and version.get('ref') not in versions['versions']:
                failures.append(f'Unresolved version alias: {name}')
    for path in source_files:
        if path.suffix == '.py':
            try:
                ast.parse(path.read_text())
            except SyntaxError as error:
                failures.append(f'Python syntax: {path.relative_to(ROOT)}: {error}')
        if path.suffix.lower() in {'.jks', '.keystore', '.pem', '.ttf', '.otf', '.woff', '.woff2'}:
            failures.append(f'Do not distribute key or font files: {path.relative_to(ROOT)}')
    android_ns = '{http://schemas.android.com/apk/res/android}'
    manifest = ET.parse(ROOT / 'app/src/main/AndroidManifest.xml').getroot()
    permissions = {node.attrib[android_ns + 'name'] for node in manifest.findall('uses-permission')}
    allowed = {'INTERNET', 'ACCESS_NETWORK_STATE', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_SPECIAL_USE',
               'POST_NOTIFICATIONS', 'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS', 'WAKE_LOCK'}
    if permissions != {'android.permission.' + p for p in allowed}:
        failures.append('Manifest permissions differ from the reviewed minimal set')
    service = manifest.find('application/service')
    if service is None or service.attrib.get(android_ns + 'exported') != 'false' or service.attrib.get(android_ns + 'foregroundServiceType') != 'specialUse':
        failures.append('Proxy service must be private and specialUse')
    app_dir = ROOT / 'app/src/main'
    app_sources = list(app_dir.rglob('*.kt'))
    production = '\n'.join(p.read_text() for p in app_sources)
    for forbidden in ['import android.webkit.WebView', 'import android.net.VpnService', 'Random.', 'Math.random(', 'DEMO']:
        if forbidden in production:
            failures.append(f'Unexpected demo or unrelated production feature: {forbidden}')
    resources: dict[str, set[str]] = {'string': set(), 'drawable': set()}
    for path in (app_dir / 'res').rglob('*.xml'):
        if path.parent.name.startswith('values'):
            for node in ET.parse(path).getroot():
                if node.tag in resources and 'name' in node.attrib:
                    resources[node.tag].add(node.attrib['name'])
        elif path.parent.name.startswith('drawable'):
            resources['drawable'].add(path.stem)
    for kind, name in re.findall(r'(?<![\w.])R\.(string|drawable)\.(\w+)', production):
        if name not in resources[kind]:
            failures.append(f'Unresolved local resource R.{kind}.{name}')
    token_data = json.loads((ROOT / 'design-tokens.json').read_text())
    theme = (app_dir / 'java/com/ningso/aps/ui/SignalTheme.kt').read_text().upper()
    for name, color in token_data['color'].items():
        if '0XFF' + color[1:].upper() not in theme:
            failures.append(f'Theme differs from reference color: {name}')
    expected_ips = {'0.0.0.0', '127.0.0.1', '192.0.2.1', '192.0.2.10', '192.0.2.11'}
    # Check shipped code, not arbitrary runner logs. Test examples use documentation addresses.
    for path in source_files:
        if path.suffix not in {'.kt', '.xml', '.kts', '.sh'}:
            continue
        text = path.read_text()
        for ip in re.findall(r'(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])', text):
            if ip not in expected_ips and ip != '999.2.3.4':  # Explicit invalid-address test.
                failures.append(f'Unreviewed literal IP in {path.relative_to(ROOT)}: {ip}')
        for pattern in (r'gh[pousr]_[A-Za-z0-9]{25,}', r'github_pat_[A-Za-z0-9_]{25,}', r'-----BEGIN .*PRIVATE KEY-----'):
            if re.search(pattern, text):
                failures.append(f'Possible credential in {path.relative_to(ROOT)}')
    unit = list(ROOT.glob('*/src/test/**/*.kt'))
    android = list(ROOT.glob('*/src/androidTest/**/*.kt'))
    report = {
        'result': 'failed' if failures else 'passed',
        'scope': 'Offline source, XML/TOML/resource/provenance checks only; NOT compilation, unit-test execution, or native UI verification.',
        'upstream_files_verified': len(lock['files']) if not any('Upstream' in f or 'upstream' in f for f in failures) else None,
        'xml_files_parsed': len(xml_files),
        'production_app_kotlin_files': len(app_sources),
        'unit_test_methods_written': sum(len(re.findall(r'@Test\b', p.read_text())) for p in unit),
        'android_test_methods_written': sum(len(re.findall(r'@Test\b', p.read_text())) for p in android),
        'build_executed': False,
        'unit_tests_executed': False,
        'android_tests_executed': False,
        'failures': failures,
    }
    return report


if __name__ == '__main__':
    result = check()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result['result'] == 'passed' else 1)
