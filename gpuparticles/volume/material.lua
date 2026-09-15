local prefix=(...):gsub('material$','')
local U,Shaders=require(prefix..'util'),require(prefix..'shaders')
local M={};M.__index=M
local defaults={buoyancy=40,dissipation=0,cooling=0.3,flowSpeed=1,compression=0.125,spread=0.5}
local liquidPresets={
  water={viscosity=0.08,velocityDamping=0.12,pressure=1,surfaceTension=10,gravity=1400,solidFriction=4,maxSpeed=1200,volumeRelaxation=100,sleepSpeed=2},
  fluid={viscosity=0.08,velocityDamping=0.12,pressure=1,surfaceTension=10,gravity=1400,solidFriction=4,maxSpeed=1200,volumeRelaxation=100,sleepSpeed=2},
  oil={viscosity=0.8,velocityDamping=0.35,pressure=0.85,surfaceTension=6,gravity=1250,solidFriction=5,maxSpeed=900,volumeRelaxation=50,sleepSpeed=2.5},
  slime={viscosity=4,velocityDamping=1.1,pressure=0.65,surfaceTension=28,gravity=900,solidFriction=7,maxSpeed=520,volumeRelaxation=12,sleepSpeed=3},
  lava={viscosity=7,velocityDamping=1.8,pressure=0.7,surfaceTension=20,gravity=750,solidFriction=9,maxSpeed=420,volumeRelaxation=5,sleepSpeed=4},
}
local bounds={buoyancy={-1000,1000},dissipation={0,20},cooling={0,20},flowSpeed={0,1},compression={0.001,1},spread={0,0.5},
  viscosity={0,20},velocityDamping={0,20},pressure={0,2},surfaceTension={0,100},gravity={-5000,5000},solidFriction={0,20},maxSpeed={1,10000},
  volumeRelaxation={0,100},sleepSpeed={0,100}}
function M.new(w,options)
  options=options or {};U.alive(w)
  U.keys(options,'name model behavior color buoyancy dissipation cooling flowSpeed compression spread viscosity velocityDamping pressure surfaceTension gravity solidFriction maxSpeed volumeRelaxation sleepSpeed force render','material')
  assert(#w.materials<8,'volume material limit is 8')
  local model=U.choice(options.model,'water','material model',{water=true,liquid=true,gas=true})
  local liquid=model=='water' or model=='liquid'
  assert(not liquid or not w.water,'a volume world supports one liquid material')
  assert(type(options.name)=='string' and #options.name>0,'volume material needs a name')
  for _,m in ipairs(w.materials) do assert(m.name~=options.name,'duplicate volume material name') end
  assert(not options.force or model=='gas','custom volume forces require the gas model')
  assert(model=='gas' or options.buoyancy==nil,'buoyancy requires a gas material')
  local behavior=model=='water' and 'settling' or model=='liquid' and U.choice(options.behavior,'water','liquid behavior',
    {settling=true,water=true,fluid=true,oil=true,slime=true,lava=true}) or nil
  assert(model=='liquid' or options.behavior==nil,'behavior requires model liquid')
  local inertial=liquid and behavior~='settling'
  assert(liquid or (options.flowSpeed==nil and options.compression==nil and options.spread==nil),'settling transport parameters require a liquid material')
  assert(not inertial or (options.flowSpeed==nil and options.compression==nil and options.spread==nil),
    'settling transport parameters require a settling liquid')
  assert(inertial or (options.viscosity==nil and options.velocityDamping==nil and options.pressure==nil and
    options.surfaceTension==nil and options.gravity==nil and options.solidFriction==nil and options.maxSpeed==nil and
    options.volumeRelaxation==nil and options.sleepSpeed==nil),
    'inertial parameters require a non-settling liquid')
  local self=setmetatable({world=w,name=options.name,model=model,owned={},keys={},
    behavior=behavior,solver=inertial and 'inertial' or liquid and 'settling' or 'gas',
    force=Shaders.hook(options.force,'force'),render=Shaders.hook(options.render,'render')},M)
  self:setColor(options.color or (model=='gas' and {0.6,0.6,0.65,0.7} or {0.34,0.68,0.70,0.88}))
  for name,default in pairs(defaults) do self[name]=U.number(options[name],model=='gas' and name=='dissipation' and 0.15 or default,name,bounds[name][1],bounds[name][2]) end
  if inertial then
    local preset=liquidPresets[behavior]
    for name,default in pairs(preset) do self[name]=U.number(options[name],default,name,bounds[name][1],bounds[name][2]) end
  end
  local ok,err=xpcall(function()
    U.guard(function()
      for _,name in ipairs{'state','next','injection'} do
        local c=U.canvas(w);self.owned[#self.owned+1]=c;self[name]=c;U.clear(c)
      end
      if liquid then
        self.flux=U.canvas(w);self.owned[#self.owned+1]=self.flux;U.clear(self.flux)
      end
      if inertial then
        for _,name in ipairs{'velocity','velocityNext','divergence','pressureField','pressureNext'} do
          self[name]=U.canvas(w);self.owned[#self.owned+1]=self[name];U.clear(self[name])
        end
      end
    end)
    local function shader(name,hook)
      local s,key=Shaders.acquire(name,hook);self.keys[#self.keys+1]=key;return s
    end
    self.drawShader=shader('draw',self.render)
    if self.solver=='settling' then self.fluxShader=shader('water-flux');self.transportShader=shader('water-transport')
    elseif inertial then
      self.forceShader=shader('liquid-force');self.divergenceShader=shader('liquid-divergence')
      self.pressureShader=shader('liquid-pressure');self.projectShader=shader('liquid-project')
      self.fluxShader=shader('liquid-flux');self.transportShader=shader('water-transport')
      self.momentumShader=shader('liquid-momentum');self.relaxShader=shader('liquid-relax')
    else self.forceShader=shader('gas-force',self.force);self.transportShader=shader('gas-transport');w:_newGas() end
  end,debug.traceback)
  if not ok then self:release();error(err,0) end
  w.materials[#w.materials+1]=self;if liquid then w.water=self end
  return self
end
function M:setColor(color)
  U.alive(self);color=U.vector(color,nil,'color',4)
  for _,c in ipairs(color) do assert(c>=0 and c<=1,'volume colors must be between 0 and 1') end
  self.color=color;return self
end
function M:set(properties)
  U.alive(self);local validated={}
  for name,value in pairs(properties) do
    assert(bounds[name],'unsupported volume parameter '..tostring(name))
    local gas=name=='buoyancy'
    local settling=name=='compression' or name=='spread' or name=='flowSpeed'
    local inertial=name=='viscosity' or name=='velocityDamping' or name=='pressure' or name=='surfaceTension' or
      name=='gravity' or name=='solidFriction' or name=='maxSpeed' or name=='volumeRelaxation' or name=='sleepSpeed'
    assert((not gas or self.model=='gas') and (not settling or self.solver=='settling') and (not inertial or self.solver=='inertial'),
      'volume parameter does not apply to '..self.solver)
    validated[name]=U.number(value,nil,name,bounds[name][1],bounds[name][2])
  end
  for name,value in pairs(validated) do self[name]=value end
  return self
end
function M:setUniform(kind,name,value)
  U.alive(self);assert(kind=='force' or kind=='render','volume hook must be force or render')
  Shaders.set(self[kind],name,value);return self
end
function M:reset()
  U.alive(self);U.guard(function() for _,c in ipairs(self.owned) do U.clear(c) end end);return self
end
function M:release()
  if self.released then return end
  self.released=true
  local w=self.world
  for i=#w.sources,1,-1 do if w.sources[i].material==self then w.sources[i]:release() end end
  for i=#w.reactions,1,-1 do local r=w.reactions[i];if r.from==self or r.to==self then r:release() end end
  for i,m in ipairs(w.materials) do if m==self then table.remove(w.materials,i);break end end
  if w.water==self then w.water=nil end
  for _,c in ipairs(self.owned) do c:release() end
  for _,key in ipairs(self.keys) do Shaders.release(key) end
  if self.model=='gas' and w.gas then
    local remaining=false
    for _,m in ipairs(w.materials) do remaining=remaining or m.model=='gas' end
    if not remaining then for _,c in ipairs(w.gas.owned) do c:release() end;w.gas=nil end
  end
end
return M
