local D={version=1,maxLayers=12,maxParticles=500000}
local utf8=require('utf8')
function D.copy(value)
  if type(value)~='table' then return value end
  local out={};for k,v in pairs(value) do out[k]=D.copy(v) end;return out
end
local function number(v,lo,hi,label)
  assert(type(v)=='number' and v==v and math.abs(v)<math.huge and v>=lo and v<=hi,(label or 'Value')..' is outside its allowed range.')
  return v
end
local function vector(v,n,lo,hi,label)
  assert(type(v)=='table' and #v==n,(label or 'Vector')..' has an invalid shape.')
  for i=1,n do number(v[i],lo,hi,label) end
end
local function text(v,label)
  assert(type(v)=='string' and #v>0 and #v<=120 and not v:find('[%z\1-\31]'),label..' must contain 1–120 bytes of text.')
  assert(utf8.len(v),label..' must be valid UTF-8 text.')
end
local function keys(value,schema,label)
  for key in pairs(value) do assert(schema[key]~=nil,'Unknown '..label..' setting: '..tostring(key)) end
end
function D.layer(name)
  return {name=name or 'New emitter',enabled=true,shape='disc',start=0,span=6,bursts={},
    emitter={max=6000,rate=1800,lifetime={0.8,1.6},position={480,470},direction=-math.pi/2,spread=0.45,
      speed={90,190},gravity={0,-30},damping=0.4,radialAcceleration=0,tangentialAcceleration=0,
      sizes={3,8,0},colors={{1,0.7,0.18,0},{1,0.28,0.04,0.65},{0.35,0.06,0.02,0}},
      sizeVariation=0.4,spin={0,0},rotation={0,0},relativeRotation=false,seed=42,blendMode='add',
      emissionArea={distribution='ellipse',x=18,y=6,angle=0,directionRelative=false}},
    turbulence={enabled=false,amplitude={25,8},frequency={3,5}},curl={enabled=false,amplitude=18,frequency=0.7},
    attractor={enabled=false,x=480,y=260,strength=900000,softening=40},
    flow={enabled=false,strength=100,frequency=2},
    ground={enabled=false,y=540},circle={enabled=false,x=480,y=320,radius=70},
    response={radius=2,bounce=0.35,friction=0.08}}
end
function D.new() return {version=D.version,name='Untitled effect',duration=6,loop=true,width=960,height=640,layers={D.layer()}} end
function D.validate(doc)
  assert(type(doc)=='table' and doc.version==D.version,'Unsupported particle project version.')
  keys(doc,{version=true,name=true,duration=true,loop=true,width=true,height=true,layers=true},'project')
  text(doc.name,'Project name');number(doc.duration,0.25,30,'Duration')
  assert(type(doc.loop)=='boolean','Loop must be boolean.')
  assert(doc.width==960 and doc.height==640,'This editor uses a 960 × 640 scene.')
  assert(type(doc.layers)=='table' and #doc.layers>=1 and #doc.layers<=D.maxLayers,'Use 1–12 emitter layers.')
  local total=0
  local schema=D.layer()
  for _,l in ipairs(doc.layers) do
    keys(l,schema,'layer')
    text(l.name,'Emitter name');assert(type(l.enabled)=='boolean','Layer visibility must be boolean.')
    l.shape=l.shape or 'disc';assert(({disc=true,spark=true,ring=true,smoke=true})[l.shape],'Invalid particle shape.')
    number(l.start,0,doc.duration,'Start time');number(l.span,0.01,30,'Emission span')
    assert(type(l.bursts)=='table' and #l.bursts<=32,'Use at most 32 bursts per layer.')
    for _,b in ipairs(l.bursts) do number(b.time,0,doc.duration,'Burst time');number(b.count,1,250000,'Burst count');assert(b.count%1==0,'Burst count must be an integer.') end
    local c=l.emitter;assert(type(c)=='table','Missing emitter settings.')
    keys(c,schema.emitter,'emitter')
    number(c.max,1,250000,'Capacity');assert(c.max%1==0,'Capacity must be an integer.');total=total+c.max
    number(c.rate,0,100000,'Emission rate');number(c.seed,0,2147483646,'Seed')
    for _,k in ipairs{'lifetime','speed','spin','rotation'} do
      vector(c[k],2,k=='lifetime' and 0.01 or -4000,k=='lifetime' and 30 or 4000,k)
      assert(c[k][2]>=c[k][1],k..' maximum must be at least its minimum.')
    end
    vector(c.position,2,-2000,3000,'Position');vector(c.gravity,2,-4000,4000,'Gravity')
    number(c.direction,-100,100,'Direction');number(c.spread,0,math.pi*2,'Spread');number(c.damping,0,20,'Damping')
    number(c.radialAcceleration,-3000,3000,'Radial acceleration');number(c.tangentialAcceleration,-3000,3000,'Tangential acceleration')
    number(c.sizeVariation,0,1,'Size variation');assert(type(c.relativeRotation)=='boolean','Relative rotation must be boolean.')
    assert(c.blendMode=='add' or c.blendMode=='alpha','Blend mode must be add or alpha.')
    assert(type(c.sizes)=='table' and #c.sizes>=1 and #c.sizes<=32,'Use 1–32 size stops.')
    for _,v in ipairs(c.sizes) do number(v,0,200,'Size') end
    assert(type(c.colors)=='table' and #c.colors>=1 and #c.colors<=32,'Use 1–32 color stops.')
    for _,v in ipairs(c.colors) do vector(v,4,0,1,'Color') end
    local a=c.emissionArea
    assert(a and ({none=true,uniform=true,normal=true,ellipse=true,borderellipse=true,borderrectangle=true})[a.distribution],'Invalid emission area.')
    keys(a,schema.emitter.emissionArea,'emission area')
    number(a.x,0,500,'Area X');number(a.y,0,500,'Area Y');number(a.angle,-100,100,'Area rotation');assert(type(a.directionRelative)=='boolean')
    for _,k in ipairs{'turbulence','curl','attractor','flow','ground','circle'} do assert(type(l[k])=='table' and type(l[k].enabled)=='boolean','Missing '..k..' settings.') end
    for _,k in ipairs{'turbulence','curl','attractor','flow','ground','circle','response'} do keys(l[k],schema[k],k) end
    vector(l.turbulence.amplitude,2,0,300,'Turbulence');vector(l.turbulence.frequency,2,0,30,'Turbulence frequency')
    number(l.curl.amplitude,0,200,'Curl');number(l.curl.frequency,0,10,'Curl frequency')
    number(l.flow.strength,-1000,1000,'Flow strength');number(l.flow.frequency,0.1,12,'Flow frequency')
    for _,p in ipairs{l.circle,l.attractor} do number(p.x,-2000,3000,'Force X');number(p.y,-2000,3000,'Force Y') end
    number(l.attractor.strength,-10000000,10000000,'Attractor strength');number(l.attractor.softening,1,300,'Attractor softening')
    number(l.ground.y,-2000,3000,'Floor Y');number(l.circle.radius,1,300,'Circle radius')
    number(l.response.radius,0,40,'Particle radius');number(l.response.bounce,0,1,'Bounce');number(l.response.friction,0,1,'Friction')
  end
  assert(total<=D.maxParticles,'The composition exceeds the 500,000 particle capacity limit.')
  return doc
end
return D
