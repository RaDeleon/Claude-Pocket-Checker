#!/usr/bin/env python3
"""Build a universal, ad-hoc signed preview without installing or launching it."""
from pathlib import Path
import hashlib
import os
import plistlib
import shutil
import subprocess
import tempfile
from make_icon import make_icon

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / 'VERSION').read_text().strip()
NAME = 'Claude Pocket Checker'
EXECUTABLE = 'ClaudePocketChecker'
IDENTIFIER = 'com.radeleon.ClaudePocketChecker'
OUT = ROOT / 'dist'


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def package():
    if os.uname().sysname != 'Darwin':
        raise SystemExit('Packaging requires macOS and Xcode Command Line Tools.')
    OUT.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='pocket-checker-release-') as temp:
        staging = Path(temp)
        app = staging / f'{NAME}.app'
        macos = app / 'Contents/MacOS'
        resources = app / 'Contents/Resources'
        macos.mkdir(parents=True)
        resources.mkdir()
        binaries = []
        for arch in ('arm64', 'x86_64'):
            scratch = ROOT / '.build' / f'distribution-{arch}'
            args = ['swift', 'build', '--disable-sandbox', '--configuration', 'release',
                    '--arch', arch, '--scratch-path', str(scratch),
                    '-Xswiftc', '-debug-prefix-map', '-Xswiftc', f'{ROOT}=.',
                    '-Xcc', f'-fdebug-prefix-map={ROOT}=.']
            print(f'Building {arch}…', flush=True)
            subprocess.run(args + ['--product', EXECUTABLE], cwd=ROOT, check=True)
            binary_dir = run(*(args + ['--show-bin-path']), cwd=ROOT)
            binaries.append(str(Path(binary_dir) / EXECUTABLE))
        binary = macos / EXECUTABLE
        run('/usr/bin/lipo', '-create', *binaries, '-output', str(binary))
        run('/usr/bin/strip', '-S', str(binary))
        binary.chmod(0o755)

        make_icon(ROOT / 'docs/assets/icon.png', resources / 'AppIcon.icns')
        shutil.copyfile(ROOT / 'LICENSE', resources / 'LICENSE.txt')
        info = {
            'CFBundleExecutable': EXECUTABLE, 'CFBundleIdentifier': IDENTIFIER,
            'CFBundleName': NAME, 'CFBundleDisplayName': NAME,
            'CFBundleShortVersionString': VERSION, 'CFBundleVersion': '5',
            'CFBundlePackageType': 'APPL', 'CFBundleIconFile': 'AppIcon',
            'LSMinimumSystemVersion': '14.0', 'NSPrincipalClass': 'NSApplication',
            'LSUIElement': True, 'NSHighResolutionCapable': True,
            'NSHumanReadableCopyright': 'Copyright 2026 Angelo De Leon. MIT license.',
        }
        with (app / 'Contents/Info.plist').open('wb') as f:
            plistlib.dump(info, f)
        run('/usr/bin/codesign', '--force', '--sign', '-', '--identifier', IDENTIFIER, str(app))
        run('/usr/bin/codesign', '--verify', '--deep', '--strict', str(app))
        archs = run('/usr/bin/lipo', '-archs', str(binary))
        if set(archs.split()) != {'arm64', 'x86_64'}:
            raise SystemExit(f'Unexpected architectures: {archs}')
        # Refuse a binary that embeds this build machine's home path.
        home = os.environ.get('HOME', '')
        if home and home.encode() in binary.read_bytes():
            raise SystemExit('Binary contains the build home path; refusing publication.')

        zip_path = OUT / f'Claude-Pocket-Checker-{VERSION}-universal-macOS.zip'
        run('/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', '--norsrc',
            str(app), str(zip_path))
        image_root = staging / 'image'
        image_root.mkdir()
        shutil.copytree(app, image_root / app.name)
        (image_root / 'Applications').symlink_to('/Applications')
        shutil.copyfile(ROOT / 'docs/INSTALL.md', image_root / 'Install instructions.md')
        dmg_path = OUT / f'Claude-Pocket-Checker-{VERSION}-universal-macOS.dmg'
        run('/usr/bin/hdiutil', 'create', '-ov', '-volname', NAME,
            '-srcfolder', str(image_root), '-fs', 'HFS+', '-format', 'UDZO', str(dmg_path))
        run('/usr/bin/hdiutil', 'verify', str(dmg_path))
        sums = ''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n'
                       for p in (dmg_path, zip_path))
        (OUT / 'SHA256SUMS-macos.txt').write_text(sums)
        print(sums, end='')


if __name__ == '__main__':
    package()
