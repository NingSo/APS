#!/usr/bin/env python3
"""Sign a verified release build; publish it before removing the named preview."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import xml.etree.ElementTree as ET

REPO = 'NingSo/APS'
OLD_PREVIEW = 'android-v0.1.0-preview.1'
ROOT = Path(__file__).resolve().parents[1]


def command(*args, env=None):
    return subprocess.check_output(args, text=True, env=env).strip()


def api(path):
    return json.loads(command('gh', 'api', f'repos/{REPO}/{path}'))


def release(tag):
    result = subprocess.run(['gh', 'api', f'repos/{REPO}/releases/tags/{tag}'], capture_output=True, text=True)
    if result.returncode == 0:
        return json.loads(result.stdout)
    if 'HTTP 404' not in result.stderr:
        raise RuntimeError('Unable to read release metadata: ' + result.stderr)
    return None


def config():
    value = json.loads((ROOT / '.github/releases/android.json').read_text())
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', value['version_name']):
        raise ValueError('Expected a stable version number')
    if value['tag'] != 'android-v' + value['version_name']:
        raise ValueError('Tag and application version must agree')
    if not isinstance(value['version_code'], int) or value['version_code'] < 2:
        raise ValueError('Increment the versionCode for the release')
    if value['replaces_preview_tag'] != OLD_PREVIEW:
        raise ValueError('Deletion is authorized only for the explicitly named Android preview')
    return value


def validate_apk(badging, signature, version, code):
    line = badging.splitlines()[0]
    expected = {'name': 'com.ningso.aps', 'versionName': version, 'versionCode': str(code)}
    fields = dict(re.findall(r"(\w+)='([^']*)'", line))
    if not all(fields.get(key) == value for key, value in expected.items()):
        raise ValueError('APK package/version does not match the official release')
    if 'application-debuggable' in badging or 'Android Debug' in signature:
        raise ValueError('Never publish a debug build or debug certificate as a formal release')
    match = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]{64})', signature)
    if not match or 'Verified using v2 scheme (APK Signature Scheme v2): true' not in signature:
        raise ValueError('Expected a valid v2 APK signature with a certificate fingerprint')
    return match.group(1).lower()


def prepare():
    cfg = config()
    if release(cfg['tag']) is not None:
        raise RuntimeError('Release/tag already has a release record; do not regenerate its signing identity or overwrite assets')
    private = Path(os.environ['RUNNER_TEMP']) / 'aps-android-signing'
    private.mkdir(mode=0o700)
    names = ['APS_ANDROID_KEYSTORE_B64', 'APS_ANDROID_STORE_PASSWORD', 'APS_ANDROID_KEY_ALIAS', 'APS_ANDROID_KEY_PASSWORD']
    supplied = [os.environ.get(name, '') for name in names]
    if any(supplied) and not all(supplied):
        raise RuntimeError('All four Android signing secrets must be configured together')
    generated = not all(supplied)
    if generated:
        if not cfg.get('bootstrap_signer') or cfg['tag'] != 'android-v1.0.0':
            raise RuntimeError('Configure the saved signing key in Actions secrets; automatic key rotation is forbidden')
        if (ROOT / '.github/releases/android-signing.sha256').exists():
            raise RuntimeError('A signing identity is already pinned; restore it instead of generating another')
        supplied = ['', secrets.token_urlsafe(36), 'aps-release', '']
        supplied[3] = supplied[1]
    for secret in (supplied[1], supplied[3]):
        print('::add-mask::' + secret, flush=True)
    keyfile = private / 'aps-release.p12'
    env = {**os.environ, 'APS_SIGN_STORE_PASSWORD': supplied[1], 'APS_SIGN_KEY_PASSWORD': supplied[3]}
    if generated:
        command('keytool', '-genkeypair', '-noprompt', '-storetype', 'PKCS12', '-keystore', str(keyfile),
                '-alias', supplied[2], '-keyalg', 'RSA', '-keysize', '4096', '-sigalg', 'SHA256withRSA',
                '-validity', '36500', '-dname', 'CN=APS Android Release',
                '-storepass:env', 'APS_SIGN_STORE_PASSWORD', '-keypass:env', 'APS_SIGN_KEY_PASSWORD', env=env)
        supplied[0] = base64.b64encode(keyfile.read_bytes()).decode('ascii')
    else:
        keyfile.write_bytes(base64.b64decode(supplied[0], validate=True))
    keyfile.chmod(0o600)
    material = dict(zip(names, supplied))
    material['generated_for_first_release'] = generated
    material_path = private / 'signing.json'
    material_path.write_text(json.dumps(material)); material_path.chmod(0o600)
    if generated:
        # The private recovery key stays with the owner, never in this public repository/runner.
        # Only authenticated ciphertext is retained in the Actions artifact, not Release assets.
        sealed = ROOT / 'signing-backup'
        sealed.mkdir()
        command('openssl', 'cms', '-encrypt', '-binary', '-aes-256-gcm', '-in', str(material_path),
                '-outform', 'DER', '-out', str(sealed / 'APS-Android-signing-backup.cms'),
                str(ROOT / '.github/releases/android-recovery-public.pem'))
        print('Generated first release signing identity; encrypted backup ready for retention.')
    else:
        print('Using existing repository signing secrets; no signing identity was generated.')


def publish():
    cfg = config(); version = cfg['version_name']; tag = cfg['tag']
    private = Path(os.environ['RUNNER_TEMP']) / 'aps-android-signing'
    material = json.loads((private / 'signing.json').read_text())
    for name in ('APS_ANDROID_STORE_PASSWORD', 'APS_ANDROID_KEY_PASSWORD'):
        print('::add-mask::' + material[name], flush=True)
    tools = Path(os.environ['ANDROID_HOME']) / 'build-tools/36.0.0'
    source = command('git', 'rev-parse', 'HEAD')
    unit = {'tests': 0, 'failures': 0, 'errors': 0, 'skipped': 0}
    for module in ('app', 'proxycore'):
        reports = list((ROOT / module / 'build/test-results/testDebugUnitTest').glob('TEST-*.xml'))
        if not reports:
            raise RuntimeError('Missing executed unit-test reports for ' + module)
        for report in reports:
            suite = ET.parse(report).getroot()
            for key in unit:
                unit[key] += int(suite.attrib.get(key, 0))
    if not unit['tests'] or unit['failures'] or unit['errors']:
        raise RuntimeError('Release unit test verification failed')
    out = ROOT / 'release-dist'; out.mkdir(exist_ok=True)
    unsigned = ROOT / 'app/build/outputs/apk/release/app-release-unsigned.apk'
    apk = out / f'APS-Android-{version}.apk'
    env = {**os.environ, 'APS_SIGN_STORE_PASSWORD': material['APS_ANDROID_STORE_PASSWORD'],
           'APS_SIGN_KEY_PASSWORD': material['APS_ANDROID_KEY_PASSWORD']}
    command(str(tools / 'apksigner'), 'sign', '--ks', str(private / 'aps-release.p12'),
            '--ks-key-alias', material['APS_ANDROID_KEY_ALIAS'], '--ks-pass', 'env:APS_SIGN_STORE_PASSWORD',
            '--key-pass', 'env:APS_SIGN_KEY_PASSWORD', '--v4-signing-enabled', 'false', '--out', str(apk), str(unsigned), env=env)
    signature = command(str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(apk))
    badging = command(str(tools / 'aapt'), 'dump', 'badging', str(apk))
    fingerprint = validate_apk(badging, signature, version, cfg['version_code'])
    pinned = ROOT / '.github/releases/android-signing.sha256'
    if pinned.exists() and fingerprint != pinned.read_text().strip():
        raise RuntimeError('Signing certificate differs from the established release identity')
    command(str(tools / 'zipalign'), '-c', '-P', '16', '4', str(apk))
    (out / 'APK-SIGNATURE.txt').write_text(signature + '\n')
    run_url = f'https://github.com/{REPO}/actions/runs/' + os.environ['GITHUB_RUN_ID']
    apk_hash = hashlib.sha256(apk.read_bytes()).hexdigest()
    provenance = {'source_sha': source, 'ci_run': run_url, 'release_tag': tag,
                  'version_name': version, 'version_code': cfg['version_code'], 'application_id': 'com.ningso.aps',
                  'variant': 'release', 'debuggable': False, 'apk_sha256': apk_hash,
                  'signer_sha256': fingerprint, 'unit_tests': unit, 'unit_test_variant': 'debug', 'owner_functional_acceptance': True}
    (out / 'BUILD-PROVENANCE.json').write_text(json.dumps(provenance, indent=2) + '\n')
    note = f'''# APS Android {version} — 正式版 / Stable release

下载 `{apk.name}` 安装；Source code ZIP/TAR 是源码，不是安装包。
Download the APK asset, not the automatic source archives.

- 应用版本 / Version: `{version}` (versionCode `{cfg['version_code']}`)
- 正式包名 / Application ID: `com.ningso.aps`
- 构建 / Build: Release, not debuggable, RSA release signing certificate (not Android Debug).
- 系统 / Requires: Android 8.0+ (API 26).
- 源码 / Source: `{source}`
- 构建与校验 / Build and checks: {run_url}
- 发布证书 SHA-256 / Signing certificate: `{fingerprint}`

功能和界面沿用项目所有者已验收的 Android 版本；本次只调整版本与发布打包。
The owner has accepted the Android functionality. This change updates versioning and distribution only.
Unit tests ({unit['tests']}, existing debug test variant), Release Lint/build, APK signing and ZIP alignment checks passed.
本次自动化校验不代表重新执行了真机验收。

## 安装与升级 / Installation and updates
允许下载此文件的浏览器或文件管理器安装应用，打开 APK 完成安装。
正式版包名不含 `.debug`，可与旧测试版并存，不会覆盖或删除旧测试版的数据。
The stable app can coexist with `com.ningso.aps.debug`; its settings do not migrate automatically.
请勿同时启动两份应用占用相同代理端口。后续正式版必须使用同一发布密钥签名。
Do not start both copies on the same ports. Future stable updates must retain the signing identity.

仅在可信局域网开启；HTTP/HTTPS CONNECT、SOCKS5 TCP CONNECT，无密码鉴权，不支持 UDP/BIND。
Trusted LAN only. No authentication; never expose the listening ports directly to the internet.
This is an Android release. The iOS release is unchanged.
'''
    (out / 'INSTALL.md').write_text(note)
    payloads = [apk, out / 'APK-SIGNATURE.txt', out / 'BUILD-PROVENANCE.json', out / 'INSTALL.md']
    (out / 'SHA256SUMS.txt').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in payloads))
    payloads.append(out / 'SHA256SUMS.txt')
    if release(tag) is not None:
        raise RuntimeError('Refusing to overwrite an existing release')
    command('gh', 'release', 'create', tag, '--target', source, '--draft',
            '--title', f'APS Android {version} — 正式版', '--notes-file', str(out / 'INSTALL.md'))
    command('gh', 'release', 'upload', tag, *[str(p) for p in payloads])
    command('gh', 'release', 'edit', tag, '--draft=false', '--prerelease=false', '--latest')
    published = release(tag)
    if published['draft'] or published['prerelease']:
        raise RuntimeError('New release is not publicly stable')
    remote_apk = [asset for asset in published['assets'] if asset['name'] == apk.name]
    if len(remote_apk) != 1 or remote_apk[0]['digest'] != 'sha256:' + apk_hash:
        raise RuntimeError('Published APK integrity verification failed; retaining preview')
    if api('git/ref/tags/' + tag)['object']['sha'] != source:
        raise RuntimeError('Release tag does not point at the built source')
    previous = release(OLD_PREVIEW)
    if previous:
        if previous['id'] != 400601016 or not previous['prerelease']:
            raise RuntimeError('Preview changed unexpectedly; will not delete it')
        command('gh', 'release', 'delete', OLD_PREVIEW, '--yes')
    print(json.dumps({'release': published['html_url'], 'apk': remote_apk[0]['browser_download_url'],
                      'preview_deleted': release(OLD_PREVIEW) is None, **provenance}, indent=2))


if __name__ == '__main__':
    os.chdir(ROOT)
    if os.environ.get('GH_REPO') != REPO or os.environ.get('GITHUB_REF') != 'refs/heads/main':
        raise SystemExit('Only the owned repository main branch may publish')
    {'prepare': prepare, 'publish': publish}[sys.argv[1]]()
