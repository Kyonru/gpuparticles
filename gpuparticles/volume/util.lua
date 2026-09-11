local U={}
function U.keys(options,allowed,context)
  assert(type(options)=='table','volume '..context..' requires a table')
  for name in pairs(options) do
    assert(type(name)=='string' and (' '..allowed..' '):find(' '..name..' ',1,true),'unsupported volume '..context..' field '..tostring(name))
  end
end
function U.number(v,default,name,min,max,integer)
  if v==nil then v=default end
  assert(type(v)=='number' and v==v and math.abs(v)<math.huge and (not min or v>=min) and
    (not max or v<=max) and (not integer or v%1==0),'gpuparticles volume: invalid '..name)
  return v
end
function U.vector(v,default,name,n)
  v=v or default;assert(type(v)=='table' and #v==n,'gpuparticles volume: invalid '..name)
  local result={};for i=1,n do result[i]=U.number(v[i],nil,name) end
  return result
end
function U.choice(v,default,name,choices)
  v=v or default;assert(choices[v],'gpuparticles volume: unsupported '..name..' '..tostring(v));return v
end
function U.alive(object)
  assert(not object.released and not (object.world and object.world.released),'gpuparticles volume: object is released')
end
function U.begin()
  local g=love.graphics
  g.push('all');g.origin();g.setShader();g.setScissor();g.setColor(1,1,1,1)
  g.setStencilTest();g.setDepthMode();g.setMeshCullMode('none');g.setWireframe(false)
  g.setColorMask(true,true,true,true);g.setBlendMode('replace','premultiplied')
end
function U.guard(fn)
  U.begin();local ok,err=xpcall(fn,debug.traceback);love.graphics.pop()
  if not ok then error(err,0) end
end
function U.canvas(w)
  local c=love.graphics.newCanvas(w.columns,w.rows,{format='rgba32f',dpiscale=1,msaa=0})
  c:setFilter('nearest','nearest');c:setWrap('clamp','clamp');return c
end
function U.clear(c)
  love.graphics.setCanvas(c);love.graphics.clear(0,0,0,0)
end
function U.send(s,name,value) if s:hasUniform(name) then s:send(name,value) end end
function U.bind(w,s)
  U.send(s,'u_grid',w.grid);U.send(s,'u_cell',w.cell);U.send(s,'u_terrain',w.terrain)
  U.send(s,'u_circle',w.circle);U.send(s,'u_time',w.time)
  love.graphics.setShader(s)
end
function U.pass(w,s,target,input)
  love.graphics.setCanvas(target);U.bind(w,s);love.graphics.draw(input)
end
function U.swap(m) m.state,m.next=m.next,m.state end
return U
