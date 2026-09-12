local D=require('editor_support.document')
local palette=require('editor_support.palette')
local function color(c,a) return {c[1],c[2],c[3],a} end
local P={names={'Ember fountain','Arcane bloom','Colliding rain','Impact burst','Pixel embers','Spectral wisps','Colliding droplets'}}
function P.make(index)
  local d=D.new();d.name=P.names[index or 1]
  local l=d.layers[1]
  if index==7 then
    l.name='Colliding droplets';l.emitter.max=1024;l.emitter.rate=256;l.emitter.lifetime={4,4}
    l.emitter.position={480,60};l.emitter.emissionArea={distribution='uniform',x=70,y=0,angle=0,directionRelative=false}
    l.emitter.direction=math.pi/2;l.emitter.spread=0.15;l.emitter.speed={80,100};l.emitter.gravity={0,220};l.emitter.damping=0.1
    l.emitter.sizes={12};l.emitter.blendMode='alpha';l.emitter.colors={color(palette.purple,0.8),color(palette.red,0.75),color(palette.pink,0)}
    l.ground.enabled=true;l.response={radius=6,bounce=0.15,friction=0.05}
    l.selfCollision={enabled=true,radius=6,bounce=0.2,strength=0.8,iterations=1}
  elseif index==5 then
    l.name='Pixel sparks';l.emitter.sizes={16,12,8};l.emitter.blendMode='alpha';l.emitter.rate=300;l.emitter.max=2000
    l.emitter.speed={55,180};l.emitter.gravity={0,-20};l.emitter.lifetime={1.2,2.6};l.emitter.spread=0.8
    l.emitter.colors={color(palette.yellow,1),color(palette.pink,1),color(palette.purple,0)}
    l.appearance.pixelSize=4;l.appearance.levels=4;l.appearance.outline=1
    l.sprite=require('editor_support.sprites').make('sparks');l.turbulence.enabled=true
  elseif index==6 then
    l.name='Spectral wisps';l.shape='ring';l.emitter.blendMode='alpha';l.emitter.position={480,380};l.emitter.spread=math.pi*2
    l.emitter.rate=160;l.emitter.max=1200;l.emitter.speed={12,80};l.emitter.gravity={0,-35};l.emitter.sizes={10,38,60}
    l.emitter.colors={color(palette.red,0),color(palette.purple,0.84),color(palette.pink,0)}
    l.curl.enabled=true;l.curl.amplitude=24;l.appearance.dissolve=0.18;l.appearance.distortion=3
    l.appearance.glow=0.8;l.appearance.glowRadius=5;l.appearance.outline=1
    l.appearance.outlineColor={palette.red[1],palette.red[2],palette.red[3]}
  elseif index==2 then
    l.name='Orbiting filaments';l.emitter.position={480,340};l.emitter.spread=math.pi*2;l.emitter.speed={8,32}
    l.emitter.emissionArea={distribution='borderellipse',x=90,y=90,angle=0,directionRelative=true}
    l.emitter.gravity={0,0};l.emitter.tangentialAcceleration=65;l.emitter.radialAcceleration=-30
    l.emitter.colors={color(palette.red,0),color(palette.purple,0.75),color(palette.pink,0)};l.curl.enabled=true;l.curl.amplitude=9
    local core=D.copy(l);core.name='Soft halo';core.emitter.max=1200;core.emitter.rate=280;core.emitter.sizes={8,34,0};core.emitter.colors={color(palette.purple,0),color(palette.red,0.10),color(palette.yellow,0)}
    core.emitter.seed=84;d.layers={core,l}
  elseif index==3 then
    l.name='Water droplets';l.emitter.max=16000;l.emitter.rate=5000;l.emitter.position={480,60}
    l.emitter.emissionArea.x=250;l.emitter.emissionArea.y=1;l.emitter.emissionArea.distribution='uniform'
    l.emitter.direction=math.pi/2;l.emitter.spread=0;l.emitter.speed={90,150};l.emitter.gravity={0,300};l.emitter.damping=0
    l.emitter.lifetime={2.4,3};l.emitter.sizes={2,3,0};l.emitter.colors={color(palette.purple,0.65),color(palette.red,0.7),color(palette.yellow,0)}
    l.ground.enabled=true;l.circle.enabled=true;l.response.bounce=0.3
    local mist=D.layer('Ground mist');mist.emitter.position={480,532};mist.emitter.emissionArea.x=210;mist.emitter.rate=350;mist.emitter.max=1500
    mist.emitter.speed={4,20};mist.emitter.gravity={0,-8};mist.emitter.sizes={8,32,65};mist.emitter.colors={color(palette.purple,0),color(palette.red,0.04),color(palette.yellow,0)}
    d.layers={l,mist}
  elseif index==4 then
    d.duration=4;l.name='Impact sparks';l.span=0.1;l.bursts={{time=0.08,count=2200}};l.emitter.rate=0
    l.emitter.position={480,340};l.emitter.spread=math.pi*2;l.emitter.speed={120,390};l.emitter.gravity={0,160};l.emitter.damping=1.1
    l.emitter.sizes={4,2,0};l.emitter.lifetime={0.6,1.6};l.emitter.colors={color(palette.yellow,1),color(palette.pink,0.85),color(palette.purple,0)}
    local flash=D.copy(l);flash.name='Flash';flash.bursts={{time=0.08,count=60}};flash.emitter.max=100;flash.emitter.speed={0,35};flash.emitter.gravity={0,0}
    flash.emitter.sizes={6,70,0};flash.emitter.lifetime={0.15,0.3};flash.emitter.colors={color(palette.yellow,0.65),color(palette.pink,0.18),color(palette.purple,0)}
    local smoke=D.copy(l);smoke.name='Afterglow';smoke.bursts={{time=0.15,count=450}};smoke.emitter.max=600;smoke.emitter.speed={20,95};smoke.emitter.gravity={0,-25}
    smoke.emitter.lifetime={1.3,2.4};smoke.emitter.sizes={10,38,60};smoke.emitter.colors={color(palette.pink,0),color(palette.pink,0.08),color(palette.purple,0)}
    d.layers={smoke,flash,l}
  else
    l.name='Flame';l.turbulence.enabled=true;l.curl.enabled=true;l.curl.amplitude=8
    l.emitter.sizes={6,18,0};l.emitter.speed={65,135};l.emitter.emissionArea.x=35
    local sparks=D.copy(l);sparks.name='Rising embers';sparks.emitter.max=3500;sparks.emitter.rate=700;sparks.emitter.speed={140,270}
    sparks.emitter.gravity={0,55};sparks.emitter.sizes={2,3,0};sparks.emitter.lifetime={1,2.6};sparks.emitter.seed=128;sparks.curl.amplitude=18
    sparks.emitter.colors={color(palette.yellow,0.9),color(palette.pink,0.7),color(palette.purple,0)}
    local smoke=D.copy(l);smoke.name='Smoke veil';smoke.shape='smoke';smoke.emitter.max=1200;smoke.emitter.rate=250;smoke.emitter.position[2]=435
    smoke.emitter.speed={25,65};smoke.emitter.lifetime={2,3};smoke.emitter.sizes={12,52,80};smoke.emitter.blendMode='alpha';smoke.emitter.seed=256
    smoke.emitter.colors={color(palette.pink,0),color(palette.red,0.10),color(palette.purple,0)}
    d.layers={smoke,l,sparks}
  end
  return D.validate(d)
end
return P
