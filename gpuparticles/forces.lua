-- Each force returns a pure displacement (analytic) or acceleration (stateful).
local M={}
local function vector(v,default)
  if type(v)=='number' then return {v,v} end
  return v or default
end
function M.turbulence(options)
  options=options or {}
  return {kind='turbulence', amplitude=vector(options.amplitude,{10,10}), frequency=vector(options.frequency,{2,3})}
end
function M.curl(options)
  options=options or {}
  return {kind='curl',amplitude=options.amplitude or 20,frequency=options.frequency or 1}
end
function M.acceleration(x,y) return {kind='acceleration',value={x,y}} end
function M.custom(options)
  assert(type(options)=='table','gpuparticles: custom force needs a descriptor')
  return {kind='custom',name=options.name,code=options.code,uniforms=options.uniforms or {},stateful=options.stateful or false}
end
local noise=[[
float forceHash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float forceNoise(vec2 p) {
    vec2 i=floor(p),f=fract(p); vec2 u=f*f*(3.0-2.0*f);
    return mix(mix(forceHash(i),forceHash(i+vec2(1,0)),u.x),
      mix(forceHash(i+vec2(0,1)),forceHash(i+vec2(1,1)),u.x),u.y);
}
vec2 forceCurl(vec2 p) {
    const float h=0.01;
    return vec2(forceNoise(p+vec2(0,h))-forceNoise(p-vec2(0,h)),
      forceNoise(p-vec2(h,0))-forceNoise(p+vec2(h,0)))/(2.0*h);
}
]]
local function identifier(s)
  return type(s)=='string' and s:match('^[a-zA-Z_][a-zA-Z0-9_]*$')
end
function M.compose(list, mode)
  local ordered={}
  for i,f in ipairs(list) do
    assert(type(f)=='table','gpuparticles: forces must be descriptors from gpuparticles.forces')
    assert(f.kind=='turbulence' or f.kind=='curl' or f.kind=='acceleration' or f.kind=='custom',
      'gpuparticles: unsupported force; use an analytic GLSL displacement or mark an acceleration stateful')
    assert(not f.stateful or mode=='stateful','gpuparticles: force '..(f.name or tostring(i))..' requires stateful mode')
    ordered[i]=f
  end
  table.sort(ordered,function(a,b) return (a.kind..(a.name or '')..(a.code or ''))<(b.kind..(b.name or '')..(b.code or '')) end)
  local source,displacements,accelerations,uniforms={noise},{},{},{}
  local function uniform(name,value)
    local gltype=type(value)=='table' and ('vec'..#value) or 'float'
    assert(gltype=='float' or gltype=='vec2' or gltype=='vec3' or gltype=='vec4','gpuparticles: force uniforms must be numbers or vectors of 2–4 numbers')
    source[#source+1]='uniform '..gltype..' '..name..';'
    uniforms[#uniforms+1]={name=name,value=value}
  end
  for i,f in ipairs(ordered) do
    local id='force'..i
    if f.kind=='turbulence' then
      uniform(id..'amp',f.amplitude);uniform(id..'freq',f.frequency)
      displacements[#displacements+1]=id..'amp*(sin('..id..'freq*age+seed*6.2831853)-sin(vec2(seed*6.2831853)))'
    elseif f.kind=='curl' then
      uniform(id..'amp',f.amplitude);uniform(id..'freq',f.frequency)
      displacements[#displacements+1]=id..'amp*(forceCurl(vec2(seed*31.7,seed*19.3)+vec2(age*'..id..'freq,age*0.37*'..id..'freq))-forceCurl(vec2(seed*31.7,seed*19.3)))'
    elseif f.kind=='acceleration' then
      uniform(id..'value',f.value)
      displacements[#displacements+1]='0.5*'..id..'value*age*age'
    else
      assert(identifier(f.name) and type(f.code)=='string' and #f.code>0,'gpuparticles: custom force needs a GLSL identifier name and code returning vec2')
      local code=f.code
      local names={}
      for name in pairs(f.uniforms) do names[#names+1]=name end
      table.sort(names)
      for _,name in ipairs(names) do
        assert(identifier(name),'gpuparticles: invalid force uniform name')
        uniform(id..'_'..name,f.uniforms[name])
        code=code:gsub('%f[%w_]'..name..'%f[^%w_]',id..'_'..name)
      end
      if f.stateful then
        source[#source+1]='vec2 '..id..'(vec2 p,vec2 velocity,float seed,float age) { '..code..' }'
        accelerations[#accelerations+1]=id..'(p,velocity,seed,age)'
      else
        source[#source+1]='vec2 '..id..'(float seed,float age) { '..code..' }'
        displacements[#displacements+1]=id..'(seed,age)'
      end
    end
  end
  source[#source+1]='vec2 forceDisplacement(float seed,float age) { return '..(#displacements>0 and table.concat(displacements,' + ') or 'vec2(0.0)')..'; }'
  source[#source+1]='vec2 statefulAcceleration(vec2 p,vec2 velocity,float seed,float age) { return '..(#accelerations>0 and table.concat(accelerations,' + ') or 'vec2(0.0)')..'; }'
  local fragment=table.concat(source,'\n')
  return {source=fragment,key=fragment,uniforms=uniforms}
end
function M.send(compiled,shader)
  for _,u in ipairs(compiled.uniforms) do if shader:hasUniform(u.name) then shader:send(u.name,u.value) end end
end
return M
