local Scene=require('example_support.waterfall.scene')
local Fluid=require('example_support.waterfall.fluid')
local M={}
local function read(fluid)
  local data=fluid.state:newImageData()
  local mass,added,upper,lower=0,0,0,0
  for y=0,fluid.rows-1 do for x=0,fluid.columns-1 do
    local m,a=data:getPixel(x,y);mass=mass+m;added=added+a
    if y<43 then upper=upper+m end
    if y>86 then lower=lower+m end
  end end
  data:release();return mass,added,upper,lower
end
local function picture(scene)
  local g=love.graphics
  local canvas=g.newCanvas(1280,800,{dpiscale=1,msaa=0})
  g.push('all');g.setCanvas(canvas);g.origin();g.setScissor();g.clear(0,0,0,0);scene:draw(false);g.pop()
  local data=canvas:newImageData();canvas:release();return data
end
function M.run()
  local scene=Scene.new()
  assert(not scene.fluid,'water volume must be opt-in, with no grid allocated when off')
  local drops,clock=scene.drops,scene.drops.time
  assert(scene:setWaterVolume(true));local fluid=scene.fluid
  assert(fluid.transportSteps==3 and fluid.columns==160 and fluid.rows==100)
  assert(scene.terrain:distance(100,760)<0 and scene.terrain:rockDistance(100,760)>0,
    'volume basin must exclude the decorative pool plane')
  local empty=picture(scene)
  scene:warm(12)
  assert(drops.time==clock and scene.drops==drops,'volume mode must suspend decorative particle simulation')
  local mass,added,_,lower=read(fluid)
  assert(mass>1000 and lower>100,'scene water must reach and accumulate in the bottom basin')
  assert(math.abs(mass-added)<0.1 and added<=12000*12/64+0.1,'relaxations must not multiply inflow')
  local wet=picture(scene);local difference=0
  for y=100,799,4 do for x=100,1179,4 do
    local r,g,b=wet:getPixel(x,y);local er,eg,eb=empty:getPixel(x,y)
    difference=difference+math.abs(r-er)+math.abs(g-eg)+math.abs(b-eb)
  end end
  empty:release();wet:release()
  assert(difference>100,'accumulated water must render from the volume state')
  scene:toggleInflow();scene:warm(2)
  local persisted,admitted=read(fluid)
  assert(math.abs(persisted-mass)<0.1 and math.abs(admitted-added)<0.001,'scene inflow toggle must preserve existing pools')
  local time=fluid.time;scene.paused=true;scene:update(0.1);assert(fluid.time==time,'pause must freeze water')
  scene.paused=false
  scene:setPointer(674,306,true);scene:changeRadius(10);scene:stepOnce()
  assert(fluid.circle[1]==674 and fluid.circle[2]==306 and fluid.circle[3]==55 and fluid.circle[4]==1)
  scene:toggleMouse();scene:stepOnce();assert(fluid.circle[4]==0,'circle toggle must reach water solver')
  scene:setWaterVolume(false)
  assert(not scene.fluid and not pcall(fluid.state.getWidth,fluid.state),'disabling water volume must release the grid')
  scene:stepOnce();assert(scene.drops==drops and drops.time>clock,'returning to particles must resume the existing emitter')
  assert(drops.config.max==24000 and drops.config.rate==6000,'volume option must preserve droplet capacity and rate')
  scene:setWaterVolume(true);assert(read(scene.fluid)==0,'re-enabling water volume must start empty')
  scene:release();scene:release()
  print('Water volume scene / opt-in / pool geometry / source budget / rendering / controls / layer suspension PASS')

  -- Optional feature failure must keep the already-running scene usable.
  scene=Scene.new{render=false}
  local g=love.graphics
  local original=g.getCanvasFormats
  g.getCanvasFormats=function() return {} end
  local ok,result,reason=pcall(scene.setWaterVolume,scene,true)
  g.getCanvasFormats=original
  assert(ok and result==false and reason and not scene.fluid,'unsupported water volume must degrade without losing particles')
  scene:stepOnce();assert(scene.drops.time>0);scene:release()
  local newCanvas,newShader=g.newCanvas,g.newShader
  local allocated={}
  g.newCanvas=function(...)
    local c=newCanvas(...);allocated[#allocated+1]=c;return c
  end
  g.newShader=function() error('intentional volume shader failure') end
  local success,failed=pcall(Fluid.new,{width=8,height=8,cellSize=1,source={x=1,y=1,width=0,rate=0}})
  g.newCanvas,g.newShader=newCanvas,newShader
  assert(success and not failed,'water shader failure must be recoverable')
  for _,c in ipairs(allocated) do assert(not pcall(c.getWidth,c),'failed water construction must release allocated canvases') end
  print('Water volume unsupported-GPU fallback / failed initialization cleanup PASS')
end
return M
