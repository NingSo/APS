#!/usr/bin/env python3
"""Validate and package an iPhoneOS Release app. An unsigned IPA still requires signing."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import zipfile


def command(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def validate_info(info: dict) -> None:
    assert info.get('DTPlatformName') == 'iphoneos', 'Refuse simulator binaries'
    assert info.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'Expected iPhoneOS platform'
    assert info.get('CFBundleIdentifier') == 'com.ningso.aps.ios'
    assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', info['CFBundleShortVersionString'])
    assert info.get('CFBundleExecutable') == 'APS'


def main() -> None:
    repo = os.environ['GH_REPO']
    assert repo == 'NingSo/APS'
    source = command('git', 'rev-parse', 'HEAD')
    assert source == os.environ['GITHUB_SHA']
    assert os.environ['GITHUB_REF'] == 'refs/heads/ios'
    app = Path('ios/build/Device/Build/Products/Release-iphoneos/APS.app')
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    validate_info(info)
    assert not (app / 'embedded.mobileprovision').exists(), 'This pipeline only publishes clearly unsigned IPAs'
    assert not list(app.rglob('*.xctest')), 'Never package test bundles'
    binary = app / info['CFBundleExecutable']
    architectures = command('xcrun', 'lipo', '-archs', str(binary)).split()
    assert 'arm64' in architectures and not set(architectures).intersection({'x86_64', 'i386'})
    build_info = command('xcrun', 'vtool', '-show-build', str(binary))
    assert re.search(r'platform\s+IOS\s', build_info + '\n') and 'IOSSIMULATOR' not in build_info
    version = info['CFBundleShortVersionString']
    tag = json.loads(Path('ios/release.json').read_text())['tag']
    assert re.fullmatch(r'ios-v' + re.escape(version) + r'-preview\.[0-9]+', tag)
    out = Path('ios/build/release'); out.mkdir(parents=True, exist_ok=True)
    ipa = out / f'APS-iOS-{version}-unsigned.ipa'
    with tempfile.TemporaryDirectory() as tmp:
        payload = Path(tmp) / 'Payload'; payload.mkdir()
        subprocess.run(['ditto', str(app), str(payload / 'APS.app')], check=True)
        subprocess.run(['ditto', '-c', '-k', '--keepParent', '--norsrc', str(payload), str(ipa.resolve())], check=True)
    with zipfile.ZipFile(ipa) as archive:
        assert archive.testzip() is None
        assert 'Payload/APS.app/APS' in archive.namelist()
        packaged_info = plistlib.loads(archive.read('Payload/APS.app/Info.plist'))
        validate_info(packaged_info)
        assert not any('.xctest/' in name or name.endswith('.p12') or name.endswith('.mobileprovision') for name in archive.namelist())
    ci = f"https://github.com/{repo}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
    provenance = {'source_sha': source, 'ci_run': ci, 'platform': 'iphoneos', 'architectures': architectures,
                  'configuration': 'Release', 'version': version, 'build': info['CFBundleVersion'],
                  'bundle_id': info['CFBundleIdentifier'], 'minimum_os': info['MinimumOSVersion'],
                  'signing': 'unsigned; valid Apple signing and provisioning required before installation',
                  'native_test_gate': 'All native job steps succeeded; simulator tests do not prove physical-device acceptance'}
    (out / 'BUILD-PROVENANCE.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n')
    note = f'''# APS iOS {version} — 未签名 IPA / Unsigned device IPA

**需要重签后安装。不能在 iPhone 浏览器中点击此文件直接安装。**
**Re-signing is required. This is NOT a tap-to-install or TestFlight distribution.**

附件 `{ipa.name}` 是使用 iPhoneOS SDK、Release 配置编译的 arm64 真机应用，
按 `Payload/APS.app` 打包；不是把模拟器 ZIP 改后缀。
This is an actual iPhoneOS device build, not a renamed simulator archive.

- Source / 源码: `{source}`
- Native tests and device build / 测试与构建: {ci}
- Bundle ID: `{info['CFBundleIdentifier']}`
- Minimum iOS / 最低系统: {info['MinimumOSVersion']}
- 本次未配置分发签名，也未发布到 TestFlight / App Store。
  No distribution signature, TestFlight upload or App Store release is included.

## 安装条件 / Installation requirements
使用自己的合法签名工具及 Apple 开发者身份重签，并满足目标设备的描述文件要求。
也可在 Mac 上打开源码，选择自己的 Team 和已连接的 iPhone，通过 Xcode 安装。
Use your own legitimate signing workflow and provisioning for the target device, or build
and install from source in Xcode with your own Team. This package alone cannot bypass signing.

面向普通用户分发时，应使用 TestFlight，或签发包含目标设备的 Ad Hoc IPA。
不要购买或使用来历不明的共享企业证书，不要把证书私钥、密码提交到公开仓库。
For user-friendly distribution, use TestFlight or a valid Ad Hoc IPA for registered devices.
Keep signing private keys and passwords out of the repository and release assets.

## 使用边界 / Runtime boundary
这是前台局域网代理。进入后台或锁屏停止，返回后手动启动；无密码鉴权，只用于可信局域网。
Foreground LAN proxy; backgrounding or locking stops the service. Trusted LAN only; no authentication.
模拟器回归和真机 SDK 编译通过不等于真实 iPhone Wi-Fi、热点、权限与功耗验收。
Simulator tests and device compilation do not replace physical-device network and power testing.
'''
    (out / 'INSTALL.md').write_text(note)
    sums = ''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n'
                   for p in sorted(out.iterdir()) if p.is_file() and p.name != 'SHA256SUMS.txt')
    (out / 'SHA256SUMS.txt').write_text(sums)
    probe = subprocess.run(['gh', 'release', 'view', tag, '--json', 'isDraft,targetCommitish'], capture_output=True, text=True)
    if probe.returncode == 0:
        existing = json.loads(probe.stdout)
        assert existing['isDraft'] and existing['targetCommitish'] == source, 'Refuse to overwrite an existing release'
    else:
        command('gh', 'release', 'create', tag, '--target', source, '--draft', '--prerelease',
                '--title', f'APS iOS {version} — 未签名 IPA（需重签安装）', '--notes-file', str(out / 'INSTALL.md'))
    assets = json.loads(command('gh', 'release', 'view', tag, '--json', 'assets'))['assets']
    assert not assets, 'Inspect partially uploaded drafts rather than overwrite assets'
    command('gh', 'release', 'upload', tag, *[str(p) for p in sorted(out.iterdir()) if p.is_file()])
    command('gh', 'release', 'edit', tag, '--draft=false', '--prerelease', '--latest=false')
    assert command('gh', 'api', f'repos/{repo}/git/ref/tags/{tag}', '--jq', '.object.sha') == source
    print(command('gh', 'release', 'view', tag, '--json', 'url,assets'))


if __name__ == '__main__':
    main()
