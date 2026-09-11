local shaders=require((...):gsub('resources$','shaders'))
local M={}
local owned={'quad','instances','random','colorCurve','sizeCurve','quadCurve','timelineTexture',
  'stateA','stateB','spawnTexture','motionTexture','styleTexture','emptyField','attractorTexture','selfPacked'}
local shared={'shaderKey','simShaderKey','stampShaderKey','selfPackKey','selfResolveKey'}
function M.release(e)
  for _,key in ipairs(owned) do
    if e[key] then e[key]:release();e[key]=nil end
  end
  for _,key in ipairs(shared) do
    if e[key] then shaders.release(e[key]);e[key]=nil end
  end
end
return M
