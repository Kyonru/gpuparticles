local gpu=require('gpuparticles')
local H=require('tests.volume_helpers')
local U=require('gpuparticles.volume.util')
local M={}
function M.run()
  local w=assert(gpu.newVolumeWorld{width=16,height=16,cellSize=1})
  local water=w:addMaterial{name='water',model='water',flowSpeed=0,cooling=0}
  local steam=w:addMaterial{name='steam',model='gas',buoyancy=0,cooling=0,dissipation=0}
  local source=w:newSource{material=water,position={8.5,8.5},temperature=0}
  source:emit(0.8)
  local rule=w:addReaction{from=water,to=steam,temperatureAbove=1,rate=math.log(2)}
  w:warm(0.5);assert(H.sum(steam).mass==0,'cold material must not react')
  w:addHeat(8.5,8.5,2,2,water)
  H.near(H.sum(water).heat,1.6,1e-6,'heat brush temperature')
  w:warm(1)
  local a,b=H.sum(water),H.sum(steam)
  H.near(a.mass,0.4,1e-5,'thermal conversion rate');H.near(b.mass,0.4,1e-5,'reaction target receives converted mass')
  H.near(a.mass+b.mass,0.8,1e-5,'reaction conserves combined mass')
  H.near(a.heat+b.heat,1.6,1e-5,'reaction carries heat')
  rule:stop();w:warm(0.2);H.near(H.sum(water).mass,a.mass,1e-5,'reaction stop')
  w:addHeat(8.5,8.5,2,-100);H.near(H.sum(water).heat,0,1e-7,'cooling brush clamp')
  steam:release();assert(rule.released and not w.gas,'material release must remove reactions and unused gas resources')
  w:release()
  print('Volume heat brush / thermal conversion / reaction mass and heat / lifecycle PASS')

  local worlds={}
  local function make(amplitude)
    local world=assert(gpu.newVolumeWorld{width=32,height=32,cellSize=2});worlds[#worlds+1]=world
    local m=world:addMaterial{name='smoke',model='gas',buoyancy=0,dissipation=0,cooling=0,
      force={code='return vec2(push,0.0);',uniforms={push=amplitude}},
      render={code='return vec4(tint, color.a);',uniforms={tint={1,0,0}}}}
    world:newSource{material=m,position={16,16},radius=4}:emit(20)
    return world,m
  end
  local first,m1=make(12);local second,m2=make(37)
  assert(m1.forceShader==m2.forceShader and m1.drawShader==m2.drawShader,'volume variants must share shaders independently of values')
  local function force(wd,m)
    U.guard(function()
      local s=m.forceShader;U.send(s,'u_velocity',wd.gas.state);U.send(s,'u_buoyancy',m.buoyancy)
      require('gpuparticles.volume.shaders').send(s,m.force)
      U.pass(wd,s,wd.gas.force,m.state)
    end)
    local data=wd.gas.force:newImageData();local x=data:getPixel(8,8);data:release();return x
  end
  H.near(force(first,m1),12,1e-6,'custom force uniform')
  H.near(force(second,m2),37,1e-6,'shared shader second material uniforms')
  H.near(force(first,m1),12,1e-6,'shared shader must restore first material uniforms')
  local shader=m1.forceShader;m1:setUniform('force','push',54)
  H.near(force(first,m1),54,1e-6,'runtime custom force update')
  assert(m1.forceShader==shader,'uniform changes must not rebuild volume shaders')
  local red=H.picture(first);local r,g=red:getPixel(16,16);red:release();assert(r>0.2 and g<1e-6,'custom volume render hook must run')
  m1:setUniform('render','tint',{0,1,0})
  local green=H.picture(first);r,g=green:getPixel(16,16);green:release();assert(g>0.2 and r<1e-6,'render uniform must update without recompilation')
  first:addForce(17,17,8,20,-5)
  local data=first.gas.state:newImageData();local vx,vy=data:getPixel(8,8);data:release()
  H.near(vx,20,1e-6,'gas impulse x');H.near(vy,-5,1e-6,'gas impulse y')
  first:release();second:update(1/120);second:release()
  assert(not pcall(shader.hasUniform,shader,'hook_push'),'last volume reference must release cached shaders')
  print('Volume custom GLSL / uniform updates / shared variants / gas impulses / shader release PASS')

  w=assert(gpu.newVolumeWorld{width=32,height=32,cellSize=4})
  local m=w:addMaterial{name='smoke',model='gas',buoyancy=0,cooling=0,dissipation=0,color={1,1,1,1}}
  w:newSource{material=m,position={14,14}}:emit(8)
  local pixel=H.picture(w);local pa=pixel:getPixel(12,12)
  H.near(pixel:getPixel(15,15),pa,1e-6,'pixel rendering must preserve cell blocks')
  local state=m.state
  w:setRenderStyle('smooth');local smooth=H.picture(w);local difference=0
  for y=0,31 do for x=0,31 do difference=difference+math.abs(smooth:getPixel(x,y)-pixel:getPixel(x,y)) end end
  pixel:release();smooth:release()
  assert(difference>1,'smooth rendering must reconstruct the displayed density')
  assert(state==m.state and state:getFilter()=='nearest','render style must not alter simulation filtering or state')
  local constant=w:addMaterial{name='constant',model='gas',render={code='return vec4(0.0,1.0,0.0,1.0);'}}
  w:newSource{material=constant,position={14,14}}:emit(8)
  local constantImage=H.picture(w);local _,greenValue=constantImage:getPixel(14,14);constantImage:release()
  assert(greenValue>0.9,'custom shading may optimize away default appearance uniforms')
  w:release()
  print('Volume pixel / smooth rendering separation PASS')
end
return M
