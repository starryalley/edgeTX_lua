--[[
Script: abs.lua
Author: Mark Kuo
URL: https://github.com/starryalley/edgeTX_lua
Description:

ABS (anti-lock braking system) for cars.

INPUT:
  Thr: SOURCE, should be set to the throttle channel
  CycleT: SOURCE, ABS cycle duration (ms). Must be > 10ms. Assign a global variable to this
  DutyC: SOURCE, ABS duty cycle (% of cycle time braking) (0%-100%)
  BrkTh: VALUE, brake threshold to activate ABS, default -30
  OnTh: VALUE, ON phase throttle value (-100 to 0), default is 0 which means current throttle. Otherwise set throttle to this value
  OffTh: VALUE, OFF phase throttle value (-100 to 0), defualt is -10. Note that setting this to 0 may cause the car to activate reverse instead of brake.

OUTPUT:
  Brk: this should be "add"ed to the throttle mixer so it applies the modulated brake (throttle value)

Usage in Mix:
  Multiplex must be set to "Add".

--]]

local input = {
    {"Thr", SOURCE},
    {"CycleT", SOURCE},
    {"DutyC", SOURCE},
    {"BrkTh", VALUE, -100, -10, -30},
    {"OnTh", VALUE, -100, 0, 0},
    {"OffTh", VALUE, -100, 0, -10},
}

local output = {"Brk"}


local abs_start_time = 0
local abs_active = false

local factor = 10.24

local function run(throttle, abs_cycle_time, abs_duty_cycle, brake_threshold, on_throttle, off_throttle)
    local now = getTime() * 10  -- Convert EdgeTX ticks (10ms) to milliseconds

    -- Ensure valid ABS parameters
    if abs_cycle_time < 10 then abs_cycle_time = 10 end
    if abs_duty_cycle < 0 then abs_duty_cycle = 0 end
    if abs_duty_cycle > 100 then abs_duty_cycle = 100 end

    -- test only in sim
    --abs_cycle_time = 100
    --abs_duty_cycle = 80

    -- Calculate ABS on/off timing
    local abs_on_time = abs_cycle_time * abs_duty_cycle / 100
    local abs_off_time = abs_cycle_time - abs_on_time

    -- Check if braking was applied (negative throttle)
    if throttle < brake_threshold*factor then
        if not abs_active then
            abs_start_time = now  -- Start ABS cycle
            abs_active = true
        end

        -- Calculate time within ABS cycle
        local cycle_elapsed = (now - abs_start_time) % abs_cycle_time

        -- Apply brake if within ON phase of ABS cycle
        if cycle_elapsed < abs_on_time then
            if on_throttle == 0 then
                return 0 -- ON phase: use the current throttle value
            else
                return on_throttle*factor-throttle -- ON phase: use the predefined throttle value
            end
        else
            return off_throttle*factor-throttle  -- Release brake during OFF phase
        end
    else
        abs_active = false  -- Reset ABS when throttle is released
    end

    -- no change to brake
    return 0
end

return { input = input, output = output, run = run }