local prefix=(...):gsub('material$','')
local U,Shaders=require(prefix..'util'),require(prefix..'shaders')
local M={};M.__index=M
local defaults={buoyancy=40,dissipation=0,cooling=0.3,flowSpeed=1,compression=0.125,spread=0.5}
local bounds={buoyancy={-1000,1000},dissipation={0,20},cooling={0,20},flowSpeed={0,1},compression={0.001,1},spread={0,0.5}}
function M.new(w,options)
  options=options or {};U.alive(w)
  U.keys(options,'name model color buoyancy dissipation cooling flowSpeed compression spread force render','material')
  assert(#w.materials<8,'volume material limit is 8')
  local model=U.choice(options.model,'water','material model',{water=true,gas=true})
  assert(model~='water' or not w.water,'a volume world supports one water material')
  assert(type(options.name)=='string' and #options.name>0,'volume material needs a name')
  for _,m in ipairs(w.materials) do assert(m.name~=options.name,'duplicate volume material name') end
  assert(not options.force or model=='gas','custom volume forces require the gas model')
  assert(model=='gas' or options.buoyancy==nil,'buoyancy requires a gas material')
  assert(model=='water' or (options.flowSpeed==nil and options.compression==nil and options.spread==nil),'water transport parameters require a water material')
  local self=setmetatable({world=w,name=options.name,model=model,owned={},keys={},
    force=Shaders.hook(options.force,'force'),render=Shaders.hook(options.render,'render')},M)
  self:setColor(options.color or (model=='gas' and {0.6,0.6,0.65,0.7} or {0.34,0.68,0.70,0.88}))
  for name,default in pairs(defaults) do self[name]=U.number(options[name],model=='gas' and name=='dissipation' and 0.15 or default,name,bounds[name][1],bounds[name][2]) end
  local ok,err=xpcall(function()
    U.guard(function()
      for _,name in ipairs{'state','next','injection'} do
        local c=U.canvas(w);self.owned[#self.owned+1]=c;self[name]=c;U.clear(c)
      end
      if model=='water' then
        self.flux=U.canvas(w);self.owned[#self.owned+1]=self.flux;U.clear(self.flux)
      end
    end)
    local function shader(name,hook)
      local s,key=Shaders.acquire(name,hook);self.keys[#self.keys+1]=key;return s
    end
    self.drawShader=shader('draw',self.render)
    if model=='water' then self.fluxShader=shader('water-flux');self.transportShader=shader('water-transport')
    else self.forceShader=shader('gas-force',self.force);self.transportShader=shader('gas-transport');w:_newGas() end
  end,debug.traceback)
  if not ok then self:release();error(err,0) end
  w.materials[#w.materials+1]=self;if model=='water' then w.water=self end
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
    assert((name~='buoyancy' or self.model=='gas') and ((name~='compression' and name~='spread' and name~='flowSpeed') or self.model=='water'),
      'volume parameter does not apply to '..self.model)
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
