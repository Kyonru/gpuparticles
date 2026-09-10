local command = (arg and arg[2]) or 'examples'
-- LÖVE leaves game arguments in the array; scan for our explicit commands.
for _, value in ipairs(arg or {}) do
  if value == 'test' or value == 'bench' or value == 'fallback' or value == 'examples-test' or value == 'waterfall' or value == 'waterfall-test' or value == 'comparison' or value == 'comparison-test' then command = value end
end
if command == 'comparison' then require('example_support.comparison.app').install()
elseif command == 'comparison-test' then require('tests.comparison').install()
elseif command == 'waterfall' then require('example_support.waterfall.app').install()
elseif command == 'waterfall-test' then require('tests.waterfall').install()
elseif command == 'test' then require('tests.main')
elseif command == 'bench' then require('bench.main')
elseif command == 'examples-test' then require('example_support.runner').install(nil,true)
elseif command == 'fallback' then require('tests.fallback')
else require('examples.main') end
