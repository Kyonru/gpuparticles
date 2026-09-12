local prefix=(...):gsub('example_support%.effects$','')
local gpu=require(prefix..'gpuparticles')
local palette=require(prefix..'example_support.palette')
local M={}
M.names={'gravity','damping','radial','tangential','turbulence','curl','flow','collision','heightfield','sdf','attractors','custom'}
local stateful={flow=true,collision=true,heightfield=true,sdf=true,attractors=true,custom=true}
function M.create(name,width,height)
  local owned={}
  local function texture(w,h,fn)
    local data=love.image.newImageData(w,h,'rgba32f');data:mapPixel(fn)
    local image=love.graphics.newImage(data);data:release();image:setFilter('linear','linear')
    owned[#owned+1]=image;return image
  end
  local c={max=50000,rate=16000,lifetime={1,3},position={width/2,height-80},direction=-math.pi/2,spread=0.7,
    speed={80,220},gravity={0,-40},damping=0.4,sizes={4,10,0},seed=41,
    colors={{palette.yellow[1],palette.yellow[2],palette.yellow[3],1},
      {palette.pink[1],palette.pink[2],palette.pink[3],0.75},
      {palette.purple[1],palette.purple[2],palette.purple[3],0}}}
  if name=='gravity' then c.gravity={0,170}
  elseif name=='damping' then c.damping=1.8
  elseif name=='radial' then c.radialAcceleration={80,120};c.spread=math.pi*2;c.position={width/2,height/2}
  elseif name=='tangential' then c.tangentialAcceleration={80,120};c.position={width/2,height/2};c.spread=math.pi*2
  elseif name=='turbulence' then c.forces={gpu.forces.turbulence{amplitude={35,10},frequency={5,3}}}
  elseif name=='curl' then c.forces={gpu.forces.curl{amplitude=40,frequency=0.8}}
  elseif name=='flow' then
    c.flowField={texture=texture(64,64,function(x,y) return math.sin(y/9)*140,-60+math.cos(x/8)*80,0,1 end),size={width,height}}
  elseif name=='collision' then
    c.gravity={0,300};c.collision={type='plane',y=height-80,bounce=0.75,friction=0.1,radius=3}
  elseif name=='heightfield' then
    c.gravity={0,300}
    c.collision={type='heightfield',texture=texture(128,1,function(x) return height-120+math.sin(x/12)*50,0,0,1 end),
      size={width,height},bounce=0.7,radius=3}
  elseif name=='sdf' then
    local radius=90
    c.position={width/2,80};c.direction=math.pi/2;c.gravity={0,80}
    c.collision={type='sdf',texture=texture(256,256,function(x,y)
      local dx,dy=(x+0.5)/256*width-width/2,(y+0.5)/256*height-height/2
      return math.sqrt(dx*dx+dy*dy)-radius,0,0,1
    end),size={width,height},bounce=0.8,radius=3}
  elseif name=='attractors' then c.attractors={{x=width/2,y=height/2,strength=5000000,softening=40}}
  elseif name=='custom' then
    c.forces={gpu.forces.custom{name='vortex',stateful=true,uniforms={center={width/2,height/2},strength=120},
      code='vec2 d=p-center; return vec2(-d.y,d.x)/max(length(d),20.0)*strength;'}}
  else error('unknown example: '..tostring(name)) end
  if stateful[name] then c.max=12000;c.rate=4000 end
  local emitter=gpu.newEmitter(c)
  local expected=stateful[name] and 'stateful' or 'analytic'
  assert(emitter:getMode()==expected,name..' selected the wrong mode')
  return emitter,owned
end
return M
