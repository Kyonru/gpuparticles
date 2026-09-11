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
parser.add_argument('--editor-only', action='store_true')
options = parser.parse_args()
root = Path(__file__).resolve().parents[1]


def run(command='test', expected=True, contains='PASS', arguments=()):
    result = subprocess.run([options.love, str(root), command, *arguments], text=True, capture_output=True, timeout=90)
    output = result.stdout + result.stderr
    if (result.returncode == 0) != expected or (contains and contains not in output):
        print(output)
        raise RuntimeError(f'{command}: unexpected exit {result.returncode}')
    if expected:
        print(output, end='')
    else:
        print(next((line for line in output.splitlines() if contains in line), output))
    return output


def mutate(label, filename, original, broken, expected, command='test'):
    path = root / filename
    source = path.read_bytes()
    assert source.count(original.encode()) == 1, f'{label}: mutation must have exactly one target'
    try:
        path.write_bytes(source.replace(original.encode(), broken.encode(), 1))
        run(command=command, expected=False, contains=expected)
        print(f'MUTATION CAUGHT: {label}')
    finally:
        path.write_bytes(source)


editor_mutations = [
    ('color picker opacity', 'editor_support/colorpicker.lua',
     "if kind=='alpha' then c[4]=clamp(a)", "if kind=='alpha' then c[4]=1", 'opacity selection', 'editor-test'),
    ('color picker gradient', 'editor_support/colorpicker.lua',
     'g.draw(self.brightness,sv.x,sv.y,0,sv.w,sv.h)', 'g.draw(self.brightness,sv.x,sv.y,0,sv.w,sv.h*2)', 'rendered picker brightness', 'editor-test'),
    ('numeric drag clamping', 'editor_support/ui.lua',
     'return math.max(n.min,math.min(n.max,v))', 'return v', 'numeric drag maximum clamp', 'editor-test'),
    ('numeric vertical drag', 'editor_support/ui.lua',
     "a.axis=='x' and x-a.lastX or a.lastY-y", 'x-a.lastX', 'vertical numeric drag', 'editor-test'),
    ('attractor display scale', 'editor_support/inspector.lua',
     "-1000,1000,1,1,1/10000", '-1000,1000,1,1,1/1000', 'attractor readable strength', 'editor-test'),
    ('built-in sprite animation', 'editor_support/sprites.lua',
     'masks[id](x%size,y,math.floor(x/size))', 'masks[id](x%size,y,0)', 'built-in sprite frames must animate', 'editor-test'),
    ('preview shader bounds', 'editor_support/view.lua',
     'm.runtime:draw(0,0,bounds)', 'm.runtime:draw()', 'particles must render through the full preview', 'editor-test'),
    ('native sprite-sheet dimensions', 'gpuparticles/native.lua',
     'width,height=quadWidth,quadHeight', 'width,height=e.texture:getDimensions()', 'appearance expected', 'editor-test'),
    ('pixel canvas filtering', 'editor_support/appearance.lua',
     "self.canvas:setFilter('nearest','nearest')", "self.canvas:setFilter('linear','linear')", 'appearance expected', 'editor-test'),
    ('layer dissolve', 'editor_support/appearance.lua',
     'c*step(u_dissolve,n)', 'c*step(u_dissolve*0.5,n)', 'full dissolve must remove', 'editor-test'),
    ('premultiplied layer composition', 'editor_support/appearance.lua',
     "g.setBlendMode(emitter.config.blendMode,'premultiplied')", "g.setBlendMode(emitter.config.blendMode,'alphamultiply')", 'appearance expected', 'editor-test'),
    ('editor burst timing', 'editor_support/runtime.lua',
     'self.events[self.eventIndex].time<=self.time+1e-8',
     'self.events[self.eventIndex].time<=self.time+0.02', 'burst must not fire early', 'editor-test'),
    ('editor automatic mode selection', 'editor_support/runtime.lua',
     "c.mode='auto'", "c.mode='stateful'", 'appearance effects must stay analytic', 'editor-test'),
]

plant_mutations = [
    ('anchored plant roots', 'example_support/waterfall/shaders/plants.glsl',
     'float weight=height*height;', 'float weight=1.0;', 'plant expected', 'waterfall-test'),
    ('plant circle contact', 'example_support/waterfall/plants.lua',
     'local overlap=circle.radius+8*p.scale-distance', 'local overlap=-1', 'circle contact must push', 'waterfall-test'),
]


def editor_verification():
    output = run('editor-test', arguments=('--export-fixture',))
    fixture = Path(next(line.split(' ', 1)[1] for line in output.splitlines() if line.startswith('EDITOR_EXPORT_PATH ')))
    with tempfile.TemporaryDirectory(prefix='particle-studio-export-') as folder:
        destination = Path(folder)
        shutil.copytree(root / 'gpuparticles', destination / 'gpuparticles')
        shutil.copyfile(fixture, destination / 'effect.lua')
        (destination / 'conf.lua').write_text((root / 'conf.lua').read_text())
        (destination / 'main.lua').write_text("""
function love.load()
  local ok,err=xpcall(function()
    assert(not love.filesystem.getInfo('editor_support'))
    local effect=require('effect').new()
    assert(effect.emitters[1]:getMode()=='stateful')
    assert(#effect.emitters[1].config.quads==2 and effect.appearances[1])
    effect:seek(0.7);effect:update(1/60);effect:draw();effect:release()
    print('Standalone editor export without editor files PASS')
  end,debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
function love.errorhandler(message) print(message);return function() return 1 end end
""")
        result = subprocess.run([options.love, str(destination)], text=True, capture_output=True, timeout=90)
        output = result.stdout + result.stderr
        print(output, end='')
        assert result.returncode == 0 and 'without editor files PASS' in output
    fixture.unlink()
    for arguments in ([], ['--compact'], ['--preset=3'], ['--preset=5'], ['--preset=5', '--compact'],
                      ['--preset=5', '--texture-tab'], ['--preset=6']):
        result = subprocess.run([options.love, str(root / 'editor'), '--smoke', '--capture', *arguments],
                                text=True, capture_output=True, timeout=90)
        output = result.stdout + result.stderr
        print(output, end='')
        assert result.returncode == 0 and 'Editor standalone render PASS' in output and 'EDITOR_CAPTURE ' in output
    if options.mutations:
        for mutation in editor_mutations:
            mutate(*mutation)
        run('editor-test')


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


if options.editor_only:
    editor_verification()
    print('EDITOR VERIFICATION COMPLETE')
    sys.exit(0)

if options.demos_only:
    run('waterfall-test')
    run('comparison-test')
    demo('waterfall')
    demo('comparison', '--benchmark')
    demo('comparison', '--mouse-collision')
    demo('waterfall', '--mouse-collision')
    demo('waterfall', '--plant-collision')
    if options.mutations:
        for mutation in plant_mutations:
            mutate(*mutation)
        run('waterfall-test')
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
run('editor-test')
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
    for mutation in mutations + editor_mutations + plant_mutations:
        mutate(*mutation)
    run()  # The restored code must pass again.
    run('comparison-test')
    run('editor-test')
print('VERIFICATION COMPLETE')
sys.exit(0)
