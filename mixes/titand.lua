-- Titan 30 CH3: G40 Pro drag-brake command, independent of the display.
-- Native T3 functions adjust persistent GV3 in FM0, bounded to 1..10.
-- Assumed ESC direction: -100% = minimum, +100% = maximum; verify on car.
local function run()
  local level = math.max(1, math.min(10, model.getGlobalVariable(2, 0)))
  return math.floor(-1024 + (level - 1) * 2048 / 9 + 0.5)
end
return { output = { 'Brake' }, run = run }
