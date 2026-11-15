#!/usr/bin/env python3
"""Validate the actual distributed ZIP and mounted DMG; never launch the GUI."""
from pathlib import Path
import hashlib
import plistlib
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / 'VERSION').read_text().strip()
BASE = ROOT / 'dist' / f'Claude-Pocket-Checker-{VERSION}-universal-macOS'


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def verify_app(app):
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'com.radeleon.ClaudePocketChecker'
    assert info['CFBundleShortVersionString'] == VERSION
    assert info['LSMinimumSystemVersion'] == '14.0'
    assert not any(k in info for k in ('CFBundleURLTypes', 'SMPrivilegedExecutables'))
    executable = app / 'Contents/MacOS/ClaudePocketChecker'
    assert set(run('/usr/bin/lipo', '-archs', str(executable)).split()) == {'arm64', 'x86_64'}
    run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))
    expected = {'Contents/Info.plist', 'Contents/MacOS/ClaudePocketChecker',
                'Contents/Resources/AppIcon.icns', 'Contents/Resources/LICENSE.txt',
                'Contents/_CodeSignature/CodeResources'}
    actual = {str(p.relative_to(app)) for p in app.rglob('*') if p.is_file()}
    assert actual == expected, f'Unexpected bundle contents: {actual ^ expected}'
    for arch in ('arm64', 'x86_64'):
        commands = run('/usr/bin/otool', '-arch', arch, '-l', str(executable))
        assert 'minos 14.0' in commands, f'Unexpected minimum OS for {arch}'
        libraries = run('/usr/bin/otool', '-arch', arch, '-L', str(executable))
        for line in libraries.splitlines()[1:]:
            assert line.strip().startswith(('/System/Library/', '/usr/lib/')), line
    return hashlib.sha256(executable.read_bytes()).hexdigest()


def verify():
    dmg, archive = Path(str(BASE) + '.dmg'), Path(str(BASE) + '.zip')
    sums = (ROOT / 'dist/SHA256SUMS-macos.txt').read_text().splitlines()
    for p in (dmg, archive):
        assert f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}' in sums
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert all(n.startswith('Claude Pocket Checker.app/') and '..' not in Path(n).parts
                   for n in z.namelist()), 'Unexpected ZIP member'
    with tempfile.TemporaryDirectory(prefix='pocket-checker-verify-') as temp:
        directory = Path(temp)
        run('/usr/bin/ditto', '-x', '-k', str(archive), str(directory))
        digest = verify_app(directory / 'Claude Pocket Checker.app')
        mount = directory / 'mounted'
        mount.mkdir()
        run('/usr/bin/hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint',
            str(mount), str(dmg))
        try:
            assert verify_app(mount / 'Claude Pocket Checker.app') == digest
            assert (mount / 'Applications').is_symlink()
            assert (mount / 'Applications').readlink() == Path('/Applications')
            assert (mount / 'Install instructions.md').is_file()
        finally:
            run('/usr/bin/hdiutil', 'detach', str(mount))
    print('Verified DMG and ZIP: checksums, architecture slices, macOS 14 minimum, '
          'system-only dynamic libraries, strict signatures, exact bundle contents and matching binaries.')


if __name__ == '__main__':
    verify()
