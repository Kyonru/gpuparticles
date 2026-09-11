local M = {}
function M.get()
  local g = love.graphics
  local supported, formats, limits = g.getSupported(), g.getCanvasFormats(), g.getSystemLimits()
  local name, version, vendor, device = g.getRendererInfo()
  local major, minor, revision = love.getVersion()
  local instancing = supported.instancing == true and type(g.drawInstanced) == 'function'
  return {
    version = {major, minor, revision}, renderer = {name, version, vendor, device},
    supported = supported, formats = formats, limits = limits,
    analytic = instancing and supported.glsl3 == true,
    volume = supported.glsl3 == true and supported.pixelshaderhighp == true and formats.rgba32f == true,
    stateful = instancing and supported.glsl3 == true and supported.pixelshaderhighp == true
      and formats.rgba32f == true and (limits.multicanvas or 0) >= 4,
    instancing = instancing, glsl3 = supported.glsl3 == true,
  }
end
return M
