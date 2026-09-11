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
parser.add_argument('--waterfall-only', action='store_true')
parser.add_argument('--water-volume-only', action='store_true')
parser.add_argument('--volume-api-only', action='store_true')
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

volume_mutations = [
    ('water transport blend', 'gpuparticles/volume/util.lua',
     "g.setBlendMode('replace','premultiplied')", "g.setBlendMode('alpha','alphamultiply')",
     'water gravity transfer', 'water-volume-test'),
    ('water conservation', 'gpuparticles/volume/shaders/water-transport.glsl',
     'old.r-dot(outgoing,vec4(1.0))', 'old.r-0.5*dot(outgoing,vec4(1.0))',
     'water gravity departure', 'water-volume-test'),
    ('water circle dam', 'gpuparticles/volume/shaders/common.glsl',
     'u_circle.w>0.5 ?', 'u_circle.w>1.5 ?',
     'circle dam must retain upstream water', 'water-volume-test'),
    ('water displacement conservation', 'gpuparticles/volume/shaders/water-transport.glsl',
     'return vec4(m*u_decay+added,', 'return vec4(circleDistance(p)<0.0 ? 0.0 : m*u_decay+added,',
     'conserved water budget', 'water-volume-test'),
    ('water inflow substeps', 'gpuparticles/volume/init.lua',
     "transport:send('u_injectionScale',1/self.transportSteps)", "transport:send('u_injectionScale',1)",
     'relaxations must not multiply inflow', 'water-volume-test'),
]

volume_api_mutations = [
    ('gas buoyancy', 'gpuparticles/volume/shaders/gas-force.glsl',
     'force.y-=u_buoyancy', 'force.y+=u_buoyancy', 'hot smoke buoyancy must lift', 'volume-test'),
    ('gas dissipation', 'gpuparticles/volume/shaders/gas-transport.glsl',
     'float mass=carried.r*u_decay;', 'float mass=carried.r;', 'gas exponential dissipation', 'volume-test'),
    ('gas cooling', 'gpuparticles/volume/shaders/gas-transport.glsl',
     'carried.b*u_decay*u_cooling+heat', 'carried.b*u_decay*(0.5+0.5*u_cooling)+heat', 'gas temperature cooling', 'volume-test'),
    ('gas projection', 'gpuparticles/volume/shaders/project.glsl',
     'vec2 v=at(velocity,p).xy-gradient;', 'vec2 v=at(velocity,p).xy-0.01*gradient;', 'gas pressure projection must reduce', 'volume-test'),
    ('volume shader cache', 'gpuparticles/volume/shaders.lua',
     "local key=kind..'\\n'..(hook and hook.source or '')", "local key=kind..'\\n'..(hook and hook.source or '')..tostring(hook)",
     'volume variants must share shaders', 'volume-test'),
    ('thermal conversion', 'gpuparticles/volume/shaders/reaction.glsl',
     's.r*fraction,0.0,s.b*fraction', 's.r*fraction*0.5,0.0,s.b*fraction*0.5', 'thermal conversion rate', 'volume-test'),
    ('smooth volume rendering', 'gpuparticles/volume/init.lua',
     "U.send(s,'u_smooth',self.renderStyle=='smooth')", "U.send(s,'u_smooth',false)", 'smooth rendering must reconstruct', 'volume-test'),
]

waterfall_mutations = volume_mutations + [
    ('waterfall self-collision emission rate', 'example_support/waterfall/scene.lua',
     'max=24000,rate=6000,lifetime', 'max=24000,rate=selfCollision and 512 or 6000,lifetime',
     'waterfall self collision must keep the full emitted count', 'waterfall-test'),
    ('waterfall particle contact', 'example_support/waterfall/scene.lua',
     'radius=1.5,bounce=0.1,strength=0.8,iterations=1', 'radius=0.000001,bounce=0.1,strength=0.8,iterations=1',
     'waterfall self collision must change the actual droplet stream', 'waterfall-test'),
    ('anchored plant roots', 'example_support/waterfall/shaders/plants.glsl',
     'float weight=height*height;', 'float weight=1.0;', 'plant expected', 'waterfall-test'),
    ('plant circle contact', 'example_support/waterfall/plants.lua',
     'local overlap=circle.radius+8*p.scale-distance', 'local overlap=-1', 'circle contact must push', 'waterfall-test'),
]

self_mutations = [
    ('particle pair separation', 'gpuparticles/shaders/selfresolve.glsl',
     '0.5*(diameter-distance)*u_strength', '0.25*(diameter-distance)*u_strength', 'pair separation', 'self-collision-test'),
    ('particle pair restitution', 'gpuparticles/shaders/selfresolve.glsl',
     '0.5*(1.0+u_bounce)', '0.25*(1.0+u_bounce)', 'pair bounce', 'self-collision-test'),
    ('inactive particle exclusion', 'gpuparticles/shaders/selfresolve.glsl',
     'if (neighbor.z<0.5) continue;', 'if (neighbor.z<0.0) continue;', 'inactive neighbor exclusion', 'self-collision-test'),
    ('particle collision environment projection', 'gpuparticles/shaders/selfresolve.glsl',
     'collide(p,velocity);', 'vec2 beforeCollision=p;collide(p,velocity);p=beforeCollision;', 'self collision must reapply environment projection', 'self-collision-test'),
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
    assert(effect.emitters[1].config.selfCollision and effect.emitters[1].selfPacked)
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
                      ['--preset=5', '--texture-tab'], ['--preset=6'], ['--preset=7'], ['--preset=7', '--compact']):
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


def volume_portability():
    with tempfile.TemporaryDirectory(prefix='gpuparticles-volume-api-') as folder:
        destination = Path(folder)
        shutil.copytree(root / 'gpuparticles', destination / 'gpuparticles')
        (destination / 'conf.lua').write_text((root / 'conf.lua').read_text())
        (destination / 'main.lua').write_text("""
function love.load()
  local ok,err=xpcall(function()
    assert(not love.filesystem.getInfo('example_support'))
    local gpu=require('gpuparticles')
    local world=assert(gpu.newVolumeWorld{width=64,height=64,cellSize=2,renderStyle='smooth'})
    local water=world:addMaterial{name='water',model='water'}
    local smoke=world:addMaterial{name='smoke',model='gas',
      force={code='return vec2(push,0);',uniforms={push=20}}}
    world:newSource{material=water,position={30,15},radius=6,rate=100,temperature=2}
    world:addReaction{from=water,to=smoke,temperatureAbove=1,rate=2}
    world:paintTerrain(20,40,8,true):setCircleCollider(40,30,6):setWind(10,0)
    world:warm(0.2);world:update(1/60);world:draw();world:release()
    print('Copied standalone volume API PASS')
  end,debug.traceback)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
function love.errorhandler(message) print(message);return function() return 1 end end
""")
        result = subprocess.run([options.love, str(destination)], text=True, capture_output=True, timeout=90)
        output = result.stdout + result.stderr
        print(output, end='')
        assert result.returncode == 0 and 'Copied standalone volume API PASS' in output


if options.editor_only:
    editor_verification()
    print('EDITOR VERIFICATION COMPLETE')
    sys.exit(0)

if options.volume_api_only:
    run('volume-test')
    run('water-volume-test')
    volume_portability()
    for preset in ('water', 'smoke', 'steam'):
        demo('volume', f'--preset={preset}')
        demo('volume', f'--preset={preset}', '--smooth')
    if options.mutations:
        for mutation in volume_mutations + volume_api_mutations:
            mutate(*mutation)
        run('volume-test')
        run('water-volume-test')
    print('VOLUME API VERIFICATION COMPLETE')
    sys.exit(0)

if options.water_volume_only:
    run('water-volume-test')
    demo('waterfall', '--water-volume')
    demo('waterfall', '--water-volume', '--mouse-collision')
    if options.mutations:
        for mutation in volume_mutations:
            mutate(*mutation)
        run('water-volume-test')
    print('WATER VOLUME VERIFICATION COMPLETE')
    sys.exit(0)

if options.demos_only or options.waterfall_only:
    run('waterfall-test')
    demo('waterfall')
    if not options.waterfall_only:
        run('comparison-test')
        demo('comparison', '--benchmark')
        demo('comparison', '--mouse-collision')
        demo('comparison', '--self-collision', '--benchmark')
    demo('waterfall', '--mouse-collision')
    demo('waterfall', '--plant-collision')
    demo('waterfall', '--self-collision')
    demo('waterfall', '--self-collision', '--mouse-collision')
    demo('waterfall', '--water-volume')
    demo('waterfall', '--water-volume', '--mouse-collision')
    if options.mutations:
        for mutation in waterfall_mutations:
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
run('volume-test')
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
        ('circle collision projection', 'gpuparticles/shaders/collision.glsl',
         'float circleDistance=separation-u_circle.z;', 'float circleDistance=1.0e30;',
         'circle expected 88.000000, got 90.000000'),
    ]
    for mutation in mutations + editor_mutations + waterfall_mutations + self_mutations + volume_api_mutations:
        mutate(*mutation)
    run()  # The restored code must pass again.
    run('comparison-test')
    run('editor-test')
print('VERIFICATION COMPLETE')
sys.exit(0)
