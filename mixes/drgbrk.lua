--[[
Script: drgbrk.lua
Author: Mark Kuo
URL: https://github.com/starryalley/edgeTX_lua
Description:

Drag brake for cars.

INPUT:
  Thr: SOURCE, should be set to the throttle channel
  DgB: SOURCE, the drag braking strength in percentage (-100% to 0%). Assign a global variable (set to %) to this
  Dur-ms: VALUE, the braking duration in ms. Default 1 second.
  PosThT: VALUE, positive throttle threshold to activate drag braking, default 10
  NegThT: VALUE, negative throttle threshold to activate drag braking, default -1

OUTPUT:
  DrgB: this should be "add"ed to the throttle mixer so it applies the brake

Usage in Mix:
  Multiplex must be set to "Add" (with optional Curve Func x<0, but not needed)

--]]

local input = {
    {"Thr", SOURCE},
    {"DgB", SOURCE},
    {"Dur-ms", VALUE, 5, 5000, 1000},
    {"PosThT", VALUE, -2, 20, 10},
    {"NegThT", VALUE, -20, 2, -1},
}

local output = {"DrgB"}


local brake_timer = 0 -- timestamp in ms in the near future where drag brake should stop applying
local active = false -- flag to indicate if throttle is positive (car going forward)

-- input/output range is -1024 to 1024. -1024 will be interpreted as -100 in UI
-- but the drag_brake (from global variable, which is set to -100% to 0
-- so we *10.24 here to convert from percentage to [-1024, 1024]
-- same for all value in UI that is in range 0-100
local factor = 10.24

local function run(throttle, drag_brake, brake_duration, posThr, negThr)
    local now = getTime() * 10  -- Convert EdgeTX ticks (10ms) to milliseconds

    if throttle > posThr*factor then
        active = true
    elseif throttle < negThr*factor then
        -- throttle is negative, cancel any drag brake setting
        active = false
        brake_timer = 0
    -- otherwise, we consider throttle is neutral which is where drag brake should be applied
    end

    -- throttle back to neutral after being positive, let's set brake timer
    if active and throttle > -3*factor and throttle < 3*factor then
        brake_timer = now + brake_duration
    end
    -- Apply drag brake if within brake duration
    if throttle > -3*factor and throttle < 3*factor and now < brake_timer then
        active = false
        
        return drag_brake * factor
    end

    return 0
end

return { input = input, output = output, run = run }