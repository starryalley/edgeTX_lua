--[[
Script: tractl.lua
Author: Mark Kuo
URL: https://github.com/starryalley/edgeTX_lua
Description:

Traction Control for cars.

INPUT:
  Thr: SOURCE, should be set to the throttle channel
  CycleT: SOURCE, traction control cycle duration (ms). Must be > 10ms. Assign a global variable to this
  DutyC: SOURCE, traction control duty cycle (% of cycle time braking) (0%-100%)
  ThrTh: VALUE, throttle threshold to activate traction control, default 50
  TCLt: VALUE, max throttle limit when TC is active (On phase) (0 to 100), default 50

OUTPUT:
  Thr: this should be "add"ed to the throttle mixer so it applies the modulated throttle


Usage in Mix:
  Multiplex must be set to "Add".

--]]

local input = {
    {"Thr", SOURCE},
    {"CycleT", SOURCE},
    {"DutyC", SOURCE},
    {"ThrTh", VALUE, 5, 100, 50},
    {"TCLt", VALUE, 0, 100, 50},
}

local output = {"Thr"}


local tc_start_time = 0
local tc_active = false

local factor = 10.24

local function run(throttle, tc_cycle_time, tc_duty_cycle, throttle_threshold, tc_limit)
    local now = getTime() * 10  -- Convert EdgeTX ticks to milliseconds
    local mix_line = model.getMixesCount(1) -- CH2: throttle

    -- Ensure valid TC parameters
    if tc_cycle_time < 10 then tc_cycle_time = 10 end
    if tc_duty_cycle < 0 then tc_duty_cycle = 0 end
    if tc_duty_cycle > 100 then tc_duty_cycle = 100 end

    -- Calculate TC on/off timing
    local tc_on_time = tc_cycle_time * tc_duty_cycle / 100
    local tc_off_time = tc_cycle_time - tc_on_time

    -- Activate TC when throttle is **positive** (accelerating)
    if throttle > throttle_threshold*factor then
        if not tc_active then
            tc_start_time = now  -- Start TC cycle
            tc_active = true
        end

        -- Calculate time within TC cycle
        local cycle_elapsed = (now - tc_start_time) % tc_cycle_time

        -- Apply throttle limit if within ON phase of TC cycle
        if cycle_elapsed < tc_on_time then
            return math.min(throttle, tc_limit*factor)-throttle
        end
    else
        tc_active = false  -- Reset TC when throttle is low
    end

    -- no change to throttle
    return 0
end

return { input = input, output = output, run = run }