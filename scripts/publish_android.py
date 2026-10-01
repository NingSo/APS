#!/usr/bin/env python3
"""Promote an exact, successful CI APK. Never substitute source archives or unsigned APKs."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile


def command(*args: str) -> str:
    return subprocess.check_output(args, text=True).strip()


def api(path: str) -> dict:
    return json.loads(command('gh', 'api', path))


def main() -> None:
    repo = os.environ['GH_REPO']
    assert repo == 'NingSo/APS', 'Unexpected publishing repository'
    config = json.loads(Path('.github/releases/android.json').read_text())
    tag, source, run_id = config['tag'], config['source_sha'], config['run_id']
    assert re.fullmatch(r'android-v[0-9]+\.[0-9]+\.[0-9]+-preview\.[0-9]+', tag)
    assert re.fullmatch(r'[0-9a-f]{40}', source)
    assert isinstance(run_id, int) and run_id > 0
    run = api(f'repos/{repo}/actions/runs/{run_id}')
    assert run['status'] == 'completed' and run['conclusion'] == 'success'
    assert run['head_sha'] == source and run['head_branch'] == 'main'
    assert run['event'] in ('push', 'workflow_dispatch')
    assert run['path'] == '.github/workflows/android.yml'
    assert run['head_repository']['full_name'] == repo
    # A workflow/docs-only publication commit is fine; publishing stale app code is not.
    subprocess.run(['git', 'diff', '--exit-code', source, 'HEAD', '--', 'app', 'proxycore',
                    'gradle', 'gradle.properties', 'build.gradle.kts', 'settings.gradle.kts',
                    'gradlew', 'gradlew.bat', 'scripts/bootstrap_gradle.py'], check=True)
    artifacts = api(f'repos/{repo}/actions/runs/{run_id}/artifacts')['artifacts']
    matches = [a for a in artifacts if a['name'] == config['artifact_name'] and not a['expired']]
    assert len(matches) == 1, 'Expected exactly one unexpired tested APK artifact'
    artifact = matches[0]
    expected_digest = 'sha256:' + config['artifact_sha256']
    assert artifact['digest'] == expected_digest, 'Artifact digest differs from release manifest'
    out = Path('release-dist'); out.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / 'artifact.zip'
        with archive.open('wb') as target:
            subprocess.run(['gh', 'api', f'repos/{repo}/actions/artifacts/{artifact["id"]}/zip'], stdout=target, check=True)
        assert hashlib.sha256(archive.read_bytes()).hexdigest() == config['artifact_sha256']
        with zipfile.ZipFile(archive) as zipped:
            apks = [entry for entry in zipped.infolist() if entry.filename.endswith('.apk') and not entry.is_dir()]
            assert len(apks) == 1, 'Expected exactly one APK, not a split bundle'
            apk = out / f'APS-{tag}-debug.apk'
            apk.write_bytes(zipped.read(apks[0]))
    tools = Path(os.environ['ANDROID_HOME']) / 'build-tools' / '36.0.0'
    signature = command(str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(apk))
    badging = command(str(tools / 'aapt'), 'dump', 'badging', str(apk))
    package_line = badging.splitlines()[0]
    assert "name='com.ningso.aps.debug'" in package_line
    assert "versionName='0.1.0-debug'" in package_line
    assert 'application-debuggable' in badging, 'Preview promotion expects the debug variant'
    (out / 'APK-SIGNATURE.txt').write_text(signature + '\n')
    provenance = {'source_sha': source, 'ci_run': run['html_url'], 'artifact_id': artifact['id'],
                  'artifact_sha256': config['artifact_sha256'], 'package': package_line,
                  'variant': 'debug', 'installable_on': 'Android 8.0 / API 26 or newer',
                  'release_tag': tag}
    (out / 'BUILD-PROVENANCE.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n')
    note = f'''# APS Android — 可安装测试版 / Installable preview

下载附件 `{apk.name}` 安装。Source code ZIP/TAR 不是安装包。
Download the APK asset, not the automatically generated source archives.

- 源码 / Source: `{source}`
- 构建与测试 / CI: {run['html_url']}
- 应用版本 / App version: `0.1.0-debug` (`versionCode=1`)
- 包名 / Application ID: `com.ningso.aps.debug`
- 系统 / Android: 8.0+ (API 26)
- 本附件直接来自上述已通过单元测试、Lint 和编译的 CI，未重新签名或修改。
  Exact tested CI artifact; not rebuilt or re-signed during publication.

## 安装与更新 / Installation and updates
允许下载此 APK 的浏览器或文件管理器“安装未知应用”，然后打开 APK。
This is a DEBUG-signed preview, not a production-key release. CI debug keys may differ
between runs. An existing install signed with a different key cannot be upgraded in place;
back up any needed data before deciding whether to uninstall it. We do not uninstall apps automatically.
这是 Debug 签名测试版，不是正式签名版本。不同 CI 构建的签名可能不同；签名不一致时不能直接覆盖安装。
需要保留的数据请先备份，再自行决定是否卸载旧测试版。正式长期更新需配置并安全保管固定发布密钥。

## 使用边界 / Security
只在可信局域网启动。HTTP/HTTPS CONNECT、SOCKS5 TCP CONNECT；无密码鉴权，不支持 UDP/BIND。
Trusted LAN only. No authentication; do not expose proxy ports to the public internet.

本 Release 仅含 Android APK，不包含 iPhone 可安装 IPA。
This release contains Android only; a simulator ZIP is not an iPhone installer.
'''
    (out / 'INSTALL.md').write_text(note)
    checksums = ''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n'
                        for p in sorted(out.iterdir()) if p.is_file() and p.name != 'SHA256SUMS.txt')
    (out / 'SHA256SUMS.txt').write_text(checksums)
    # Published assets are immutable here: never use --clobber or move existing tags.
    probe = subprocess.run(['gh', 'release', 'view', tag, '--json', 'isDraft'], capture_output=True, text=True)
    if probe.returncode == 0:
        assert json.loads(probe.stdout)['isDraft'], 'Release already published; use a new preview number'
    else:
        command('gh', 'release', 'create', tag, '--target', source, '--draft', '--prerelease',
                '--title', 'APS Android 0.1.0 — 可安装测试版', '--notes-file', str(out / 'INSTALL.md'))
    assert command('gh', 'api', f'repos/{repo}/git/ref/tags/{tag}', '--jq', '.object.sha') == source
    existing = json.loads(command('gh', 'release', 'view', tag, '--json', 'assets'))['assets']
    assert not existing, 'Draft already has assets; inspect it rather than overwrite'
    command('gh', 'release', 'upload', tag, *[str(p) for p in sorted(out.iterdir()) if p.is_file()])
    command('gh', 'release', 'edit', tag, '--draft=false', '--prerelease', '--latest=false')
    print(command('gh', 'release', 'view', tag, '--json', 'url,assets'))


if __name__ == '__main__':
    main()
