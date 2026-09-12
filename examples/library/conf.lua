function love.conf(t)
  t.identity = 'gpuparticles-development'
  t.version = '11.5'
  t.window.title = 'GPU particles — effect library'
  t.window.width, t.window.height = 1180, 720
  t.window.resizable = true
  t.window.vsync = 0
  t.modules.audio, t.modules.joystick, t.modules.physics = false, false, false
end
