function love.load()
  print(('LOVE %d.%d.%d'):format(love.getVersion()))
  print(love.graphics.getRendererInfo())
  for k,v in pairs(love.graphics.getSupported()) do print(k,v) end
  for k,v in pairs(love.graphics.getSystemLimits()) do print(k,v) end
  for _,f in ipairs{'rgba16f','rgba32f','rg32f','r32f'} do print(f,love.graphics.getCanvasFormats()[f]) end
  print('drawInstanced',type(love.graphics.drawInstanced))
  print('compute',type(love.graphics.dispatchThreadgroups))
  love.event.quit()
end
