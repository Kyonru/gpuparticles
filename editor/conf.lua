function love.conf(t)
  t.identity='gpuparticles-studio'
  t.version='11.5'
  t.window.title='Particle Studio — GPU effect editor'
  t.window.width,t.window.height=1440,900
  t.window.resizable=true;t.window.minwidth,t.window.minheight=1120,760
  t.window.vsync=1
  t.modules.audio,t.modules.joystick,t.modules.physics=false,false,false
end
