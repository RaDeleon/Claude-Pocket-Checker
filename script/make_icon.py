#!/usr/bin/env python3
"""Convert the project's illustrated PNG into a standard multi-size macOS icon."""
from pathlib import Path
import subprocess
import sys
import tempfile


def make_icon(source, output):
    with tempfile.TemporaryDirectory(prefix='pocket-checker-icon-') as temp:
        iconset = Path(temp) / 'AppIcon.iconset'
        iconset.mkdir()
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                suffix = '@2x' if scale == 2 else ''
                subprocess.run(['/usr/bin/sips', '-z', str(size * scale), str(size * scale),
                                str(source), '--out',
                                str(iconset / f'icon_{size}x{size}{suffix}.png')],
                               check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['/usr/bin/iconutil', '-c', 'icns', str(iconset), '-o', str(output)],
                       check=True)


if __name__ == '__main__':
    make_icon(Path(sys.argv[1]), Path(sys.argv[2]))
