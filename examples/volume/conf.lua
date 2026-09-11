function love.conf(t)
  t.identity='gpuparticles-volume'
  t.version='11.5'
  t.window.title='Material volumes — GPU water and smoke'
  t.window.width,t.window.height=1280,800
  t.window.resizable=true;t.window.minwidth,t.window.minheight=960,640
  t.window.vsync=1
  t.modules.audio,t.modules.joystick,t.modules.physics=false,false,false
end
