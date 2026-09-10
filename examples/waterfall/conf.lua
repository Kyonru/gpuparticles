function love.conf(t)
  t.identity='gpuparticles-waterfall'
  t.version='11.5'
  t.window.title='Basalt Falls — GPU waterfall'
  t.window.width,t.window.height=1280,800
  t.window.resizable=true
  t.window.minwidth,t.window.minheight=640,400
  t.window.vsync=1
  t.modules.audio,t.modules.joystick,t.modules.physics=false,false,false
end
