function love.conf(t)
  t.identity = 'gpuparticles-development'
  t.version = '11.5'
  t.window.title = 'GPU particles — SDF collision groups'
  t.window.width, t.window.height = 960, 640
  t.window.vsync = 0
  t.modules.audio, t.modules.joystick, t.modules.physics = false, false, false
end
