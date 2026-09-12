function love.conf(t)
  t.identity='gpuparticles-colliders'
  t.version='11.5'
  t.window.title='gpuparticles — moving colliders'
  t.window.width,t.window.height=1280,800
  t.window.resizable=true;t.window.minwidth,t.window.minheight=800,560
  t.window.vsync=0
  t.modules.audio,t.modules.joystick,t.modules.physics=false,false,false
end
