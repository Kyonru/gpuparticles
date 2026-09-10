#!/usr/bin/env python3
"""Run the real LÖVE tests, optionally verifying them with reversible defects."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--love', default=shutil.which('love') or '/Applications/love.app/Contents/MacOS/love')
parser.add_argument('--mutations', action='store_true')
parser.add_argument('--portable-only', action='store_true')
parser.add_argument('--demos-only', action='store_true')
options = parser.parse_args()
root = Path(__file__).resolve().parents[1]


def run(command='test', expected=True, contains='PASS'):
    result = subprocess.run([options.love, str(root), command], text=True, capture_output=True, timeout=90)
    output = result.stdout + result.stderr
    if (result.returncode == 0) != expected or (contains and contains not in output):
        print(output)
        raise RuntimeError(f'{command}: unexpected exit {result.returncode}')
    if expected:
        print(output, end='')
    else:
        print(next((line for line in output.splitlines() if contains in line), output))


def demo(name, *arguments):
    result = subprocess.run(
        [options.love, str(root / 'examples' / name), '--smoke', '--capture', *arguments],
        text=True, capture_output=True, timeout=90,
    )
    output = result.stdout + result.stderr
    print(output, end='')
    required = (f'{name.capitalize()} standalone render PASS', f'{name.upper()}_CAPTURE ')
    if result.returncode != 0 or any(marker not in output for marker in required):
        raise RuntimeError(f'{name}: exit {result.returncode}, required render/capture markers: {required}')


def portability():
    with tempfile.TemporaryDirectory(prefix='gpuparticles-standalone-') as folder:
        destination = Path(folder)
        shutil.copytree(root / 'gpuparticles', destination / 'gpuparticles')
        (destination / 'conf.lua').write_text((root / 'conf.lua').read_text())
        (destination / 'main.lua').write_text("""
function love.load()
  local ok,err=xpcall(function()
    local gpu=require('gpuparticles')
    for _,mode in ipairs{'analytic','stateful'} do
      local e=gpu.newEmitter{max=100,rate=100,lifetime=1,mode=mode,forces={gpu.forces.turbulence{}}}
      assert(e:getBackend()=='gpu' and e:getMode()==mode)
      e:warm(0.2);e:draw();e:release()
    end
    print('Copied standalone library PASS')
  end,debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
function love.errorhandler(message) print(message);return function() return 1 end end
""")
        subprocess.run([options.love, str(destination)], check=True, timeout=90)
    subprocess.run([options.love, str(root / 'examples' / 'curl'), '--smoke'], check=True, timeout=90)
    subprocess.run([options.love, str(root / 'bench')], check=True, timeout=90)


if options.demos_only:
    run('waterfall-test')
    run('comparison-test')
    demo('waterfall')
    demo('comparison', '--benchmark')
    demo('comparison', '--mouse-collision')
    demo('waterfall', '--mouse-collision')
    print('DEMO VERIFICATION COMPLETE')
    sys.exit(0)

if options.portable_only:
    portability()
    print('PORTABILITY VERIFICATION COMPLETE')
    sys.exit(0)


run()
run('fallback')
run('examples-test')
run('waterfall-test')
run('comparison-test')
if options.mutations:
    mutations = [
        ('simulation blend', 'gpuparticles/stateful.lua',
         'g.setCanvas(e.stateB);g.setShader(s)',
         "g.setCanvas(e.stateB);g.setBlendMode('alpha','alphamultiply');g.setShader(s)", 'expected 0.055555556'),
        ('nearest filtering', 'gpuparticles/stateful.lua',
         "c:setFilter('nearest','nearest')", "c:setFilter('linear','linear')", 'state filtering must be nearest'),
        ('vertex texel addressing', 'gpuparticles/shaders/render.glsl',
         '+0.5)/u_texSize', '-0.5)/u_texSize', 'expected'),
        ('analytic acceleration', 'gpuparticles/shaders/common.glsl',
         '0.5*acceleration*age*age', '0.25*acceleration*age*age', 'expected 30.000000000'),
        ('shader cache', 'gpuparticles/shaders.lua',
         'local entry=cache[id]\n  if not entry then', 'local entry=nil\n  if not entry then', 'same force set must share a shader'),
        ('comparison native pixel size', 'example_support/comparison/model.lua',
         'native:setSizes(size/16)', 'native:setSizes(size/8)',
         'comparison expected 3.000000, got 6.000000', 'comparison-test'),
        ('comparison inactive-system gating', 'example_support/comparison/model.lua',
         "return self.view=='both' or self.view==name", 'return true',
         'comparison expected', 'comparison-test'),
        ('circle collision projection', 'gpuparticles/shaders/simulate.glsl',
         'float circleDistance=separation-u_circle.z;', 'float circleDistance=1.0e30;',
         'circle expected 88.000000, got 90.000000'),
    ]
    for label, filename, original, broken, expected, *commands in mutations:
        path = root / filename
        source = path.read_bytes()
        assert source.count(original.encode()) == 1, f'{label}: mutation must have exactly one target'
        try:
            path.write_bytes(source.replace(original.encode(), broken.encode(), 1))
            run(command=commands[0] if commands else 'test', expected=False, contains=expected)
            print(f'MUTATION CAUGHT: {label}')
        finally:
            path.write_bytes(source)
    run()  # The restored code must pass again.
    run('comparison-test')
print('VERIFICATION COMPLETE')
sys.exit(0)
