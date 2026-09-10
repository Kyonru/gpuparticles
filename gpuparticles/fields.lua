-- Texture ownership stays with the caller, except for our packed attractor LUT.
local M={}
function M.new(e)
  local data=love.image.newImageData(1,1,'rgba32f')
  data:setPixel(0,0,0,0,0,0)
  e.emptyField=love.graphics.newImage(data);data:release()
  local flow=e.config.flowField
  if flow and type(flow)~='table' then flow={texture=flow} end
  local collision=e.config.collision or {}
  local attractors=e.config.attractors or {}
  e.fields={
    attractorCount=#attractors,
    flow=flow and flow.texture or e.emptyField,
    flowRegion=flow and { (flow.origin or {0,0})[1],(flow.origin or {0,0})[2],
      (flow.size or {flow.texture:getDimensions()})[1],(flow.size or {flow.texture:getDimensions()})[2]} or {0,0,1,1},
    flowEncoding=flow and flow.encoding=='unorm' and {2,-1} or {1,0},
    flowStrength=flow and (flow.strength or 1) or 0,
    collision=collision.texture or e.emptyField,
    collisionType=({plane=1,heightfield=2,sdf=3})[collision.type] or 0,
    collisionRegion={(collision.origin or {0,0})[1],collision.y or (collision.origin or {0,0})[2],
      (collision.size or {1,1})[1],(collision.size or {1,1})[2]},
    collisionEncoding={collision.scale or 1,collision.bias or 0},
    collisionResponse={collision.radius or 0,collision.bounce or 0.5,collision.friction or 0,0},
    collisionTexel={1,1},
    circle={0,0,0,0},circleResponse={0,0.5,0,0},
  }
  if collision.texture then e.fields.collisionTexel={1/collision.texture:getWidth(),1/collision.texture:getHeight()} end
  if #attractors>0 then
    data=love.image.newImageData(#attractors,1,'rgba32f')
    for i,a in ipairs(attractors) do
      data:setPixel(i-1,0,a.x or a.position[1],a.y or a.position[2],a.strength or 1000,a.softening or 10)
    end
    e.attractorTexture=love.graphics.newImage(data)
    e.attractorTexture:setFilter('nearest','nearest');data:release()
  end
end
function M.send(e,shader)
  local f=e.fields
  local c=e.config.circleCollider
  if c then
    f.circle[1],f.circle[2],f.circle[3],f.circle[4]=c.x,c.y,c.radius,c.enabled==false and 0 or 1
    f.circleResponse[1],f.circleResponse[2],f.circleResponse[3]=c.particleRadius,c.bounce,c.friction
  end
  shader:send('u_circle',f.circle);shader:send('u_circleResponse',f.circleResponse)
  shader:send('u_hasFlow',not not e.config.flowField)
  shader:send('u_flow',f.flow);shader:send('u_flowRegion',f.flowRegion)
  shader:send('u_flowEncoding',f.flowEncoding);shader:send('u_flowStrength',f.flowStrength)
  shader:send('u_attractors',e.attractorTexture or e.emptyField)
  shader:send('u_attractorCount',f.attractorCount)
  shader:send('u_collision',f.collision);shader:send('u_collisionType',f.collisionType)
  shader:send('u_collisionRegion',f.collisionRegion);shader:send('u_collisionTexel',f.collisionTexel)
  shader:send('u_collisionEncoding',f.collisionEncoding);shader:send('u_collisionResponse',f.collisionResponse)
end
function M.release(e)
  if e.attractorTexture then e.attractorTexture:release() end
  if e.emptyField then e.emptyField:release() end
end
return M
