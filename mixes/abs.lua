--[[
Script: abs.lua
Author: Mark Kuo
URL: https://github.com/starryalley/edgeTX_lua
Description:

ABS (anti-lock braking system) for cars.

INPUT:
  Thr: SOURCE, should be set to the throttle channel
  Brake: SOURCE, the braking strength in percentage (-100% to 0%). Assign a global variable (set to %) to this
  CycleT: SOURCE, ABS cycle duration (ms). Must be > 10ms. Assign a global variable to this
  DutyC: SOURCE, ABS duty cycle (% of cycle time braking) (0%-100%)

OUTPUT:
  Brk: this should be "add"ed to the throttle mixer so it applies the modulated brake (throttle value)


Usage in Mix:
  Multiplex must be set to "Replace" (with Curve Func x<0)

--]]

local input = {
    {"Thr", SOURCE},
    {"CycleT", SOURCE},
    {"DutyC", SOURCE},
    {"BrkTh", VALUE, -100, -10, -30}, -- brake threshold to activate ABS, default -30
    {"OnTh", VALUE, -100, 0, 0}, -- ON phase throttle value (-100 to 0), default is the special value 0, which means current throttle value
    {"OffTh", VALUE, -100, 0, 0}, -- OFF phase throttle value (-100 to 0), default is no brake (0)
}

local output = {"Brk"}


local previous_throttle = 0
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
                return throttle -- ON phase: use the current throttle value
            else
                return on_throttle*factor -- ON phase: use the predefined throttle value
            end
        else
            return off_throttle*factor  -- Release brake during OFF phase
        end
    else
        abs_active = false  -- Reset ABS when throttle is released
    end

    return throttle  -- Default: pass-through throttle
end

return { input = input, output = output, run = run }