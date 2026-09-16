-- Bouncer / MT12: optional Trail coast, added to the native CH2 throttle mix.
-- Input Thr = TH (untrimmed). L5 = FL1 Trail AND FL2 Coast.
-- Output is a correction, NOT an absolute throttle command.
-- GV5 in FM0 stores tenths of a second; native T5 functions save changes.
local DEADBAND = 31       -- approximately 3% of 1024
local current, lastTime, active = 0, nil, false
local function init()
  current, lastTime, active = 0, nil, false
end
local function run(throttle)
  local raw = math.max(-1024, math.min(1024, throttle or 0))
  local target = math.abs(raw) <= DEADBAND and 0 or raw
  local now = getTime()
  local enabled = getLogicalSwitchValue(4)
  -- Reset state on disable, enable, startup, clock wrap or a long pause.
  -- Enabling coast at neutral can never replay an earlier throttle value.
  if not enabled or not active or not lastTime or now < lastTime or now-lastTime > 25 then
    current, lastTime, active = target, now, enabled
    return 0
  end
  local dt = (now-lastTime)/100
  lastTime = now
  if target*current < 0 or math.abs(target) >= math.abs(current) then
    current = target
  else
    local seconds = math.max(1,math.min(50,model.getGlobalVariable(4,0)))/10
    current = target+(current-target)*math.exp(math.log(0.05)*dt/seconds)
  end
  if target == 0 and math.abs(current) <= DEADBAND then current = 0 end
  return math.floor(current-raw+0.5)
end
return { input={{'Thr', SOURCE}}, output={'Delta'}, init=init, run=run }
