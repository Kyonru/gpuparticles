#!/usr/bin/env python3
"""Capture animated documentation examples through LÖVE and encode compact GIFs."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--love', default=shutil.which('love') or '/Applications/love.app/Contents/MacOS/love')
parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg') or 'ffmpeg')
options = parser.parse_args()
root = Path(__file__).resolve().parents[1]

examples = [
    ('comparison-mouse', 'comparison', ('--mouse-collision',)),
    ('colliders', 'colliders', ()),
    ('custom-shaders', 'custom-shaders', ()),
    ('waterfall-plants', 'waterfall', ('--plant-collision',)),
    ('waterfall-volume-mouse', 'waterfall', ('--water-volume', '--mouse-collision')),
    ('volume-smoke-smooth', 'volume', ('--preset=smoke', '--smooth')),
    ('volume-steam-pixel', 'volume', ('--preset=steam',)),
    ('volume-water-pixel', 'volume', ('--preset=water',)),
]

for name, project, arguments in examples:
    command = [options.love, str(root / 'examples' / project), '--smoke', '--gif', f'--gif-name={name}', *arguments]
    result = subprocess.run(command, text=True, capture_output=True, timeout=120)
    output = result.stdout + result.stderr
    print(output, end='')
    match = re.search(r'^GIF_FRAMES (.+)$', output, re.MULTILINE)
    if result.returncode or not match:
        raise RuntimeError(f'{name}: LÖVE capture failed with exit {result.returncode}')
    pattern = Path(match.group(1))
    destination = root / 'previews' / f'{name}.gif'
    filters = (
        'fps=12,scale=960:-1:flags=lanczos,split[s0][s1];'
        '[s0]palettegen=max_colors=128:stats_mode=diff[p];'
        '[s1][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle'
    )
    subprocess.run([
        options.ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-framerate', '12',
        '-i', str(pattern), '-filter_complex', filters, '-loop', '0', str(destination),
    ], check=True, timeout=120)
    for frame in pattern.parent.glob(pattern.name.replace('%03d', '*')):
        frame.unlink()
    docs = root / 'docs' / 'assets' / 'images' / destination.name
    shutil.copy2(destination, docs)
    print(f'GIF_CAPTURE {destination} ({destination.stat().st_size // 1024} KiB)')

print('GIF CAPTURE COMPLETE')
