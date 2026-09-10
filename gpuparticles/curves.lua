local M={}
local function texture(values, color)
  assert(#values>0, 'gpuparticles: curves need at least one stop')
  assert(#values<=love.graphics.getSystemLimits().texturesize,'gpuparticles: too many curve stops for this GPU')
  local data=love.image.newImageData(#values,1,'rgba32f')
  for i,v in ipairs(values) do
    if color then data:setPixel(i-1,0,v[1],v[2],v[3],v[4] or 1)
    else data:setPixel(i-1,0,v,0,0,1) end
  end
  local img=love.graphics.newImage(data)
  img:setFilter('nearest','nearest')
  data:release()
  return img
end
function M.refresh(e)
  if e.colorCurve then e.colorCurve:release();e.sizeCurve:release();e.quadCurve:release() end
  e.colorCurve=texture(e.config.colors,true)
  e.sizeCurve=texture(e.config.sizes,false)
  local uv={}
  for i,q in ipairs(e.config.quads) do
    local x,y,w,h=q:getViewport()
    local tw,th=q:getTextureDimensions()
    uv[i]={x/tw,y/th,w/tw,h/th}
  end
  if #uv==0 then uv[1]={0,0,1,1} end
  e.quadCurve=texture(uv,true)
end
function M.send(e,shader)
  shader:send('u_colors',e.colorCurve); shader:send('u_colorCount',#e.config.colors)
  shader:send('u_sizes',e.sizeCurve); shader:send('u_sizeCount',#e.config.sizes)
  shader:send('u_quads',e.quadCurve); shader:send('u_quadCount',math.max(1,#e.config.quads))
end
function M.release(e)
  e.colorCurve:release();e.sizeCurve:release();e.quadCurve:release()
end
return M
