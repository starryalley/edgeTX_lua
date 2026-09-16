-- coast.lua
-- EdgeTX Mixer Script
--
-- Simulates free coasting on worm-drive crawlers by continuing to
-- drive the motor after throttle is reduced.
--
-- Behaviour:
--   More throttle        -> immediate
--   Less throttle        -> exponential coast
--   Forward -> reverse   -> immediate (brake/reverse)
--   Reverse -> forward   -> immediate
--   Coasting is always active; Knob controls the coast time.
--
-- Inputs are selected in EdgeTX Custom Scripts:
--   Thr    = throttle input
--   Knob   = knob/pot controlling coast time


----------------------------------------------------------------------
-- USER SETTINGS
----------------------------------------------------------------------

-- Minimum coast time when knob is fully counter-clockwise.
-- Set to 0.00 if you want the minimum position to effectively disable
-- coasting.
local COAST_TIME_MIN = 0.10       -- seconds

-- Coast time at knob centre.
local COAST_TIME_MID = 1.20       -- seconds

-- Maximum coast time when knob is fully clockwise.
local COAST_TIME_MAX = 2.20       -- seconds


-- Exponential curve strength.
--
-- This defines how much of the old throttle remains after COAST_TIME.
--
-- 0.10 = after COAST_TIME, 10% of the original difference remains
-- 0.05 = after COAST_TIME,  5% remains
-- 0.02 = after COAST_TIME,  2% remains
--
-- Smaller = stronger initial deceleration / reaches target sooner.
-- Larger  = softer, longer tail.
--
-- 0.05 is a good starting point.
local EXP_REMAIN = 0.05


-- Neutral deadband in percent.
-- Once both target and simulated output get this close to neutral,
-- snap to exactly zero.
local NEUTRAL_DEADBAND = 3.0      -- percent


-- If throttle direction changes, bypass coasting immediately.
--
-- true:
--   +70 -> -50 = immediate
--   Lets reverse act as braking, like a normal surface RC.
--
-- false:
--   +70 -> -50 first coasts toward zero.
local REVERSE_BYPASS = true


-- Safety / numerical settings
local MAX_DT = 0.10               -- seconds
local MIN_OUTPUT_CHANGE = 0.05    -- percent


----------------------------------------------------------------------
-- INTERNAL STATE
----------------------------------------------------------------------

local current = 0.0
local lastTime = 0
local initialized = false


----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------

local function clamp(x, lo, hi)
    if x < lo then return lo end
    if x > hi then return hi end
    return x
end


-- Convert EdgeTX source (-1024 .. +1024) to percent (-100 .. +100)
local function toPercent(x)
    return clamp(x / 10.24, -100.0, 100.0)
end


-- Convert percent back to EdgeTX mixer value
local function toEdgeTX(x)
    return math.floor(clamp(x, -100.0, 100.0) * 10.24 + 0.5)
end


-- Map knob -1024..+1024 to coast time.
--
-- Uses separate MIN->MID and MID->MAX ranges so the centre position
-- always corresponds exactly to COAST_TIME_MID.
local function knobToCoastTime(knob)
    local k = clamp(knob / 1024.0, -1.0, 1.0)

    if k <= 0 then
        -- -1 .. 0  => MIN .. MID
        return COAST_TIME_MIN
            + (COAST_TIME_MID - COAST_TIME_MIN) * (k + 1.0)
    else
        -- 0 .. +1 => MID .. MAX
        return COAST_TIME_MID
            + (COAST_TIME_MAX - COAST_TIME_MID) * k
    end
end


local function sign(x)
    if x > NEUTRAL_DEADBAND then
        return 1
    elseif x < -NEUTRAL_DEADBAND then
        return -1
    else
        return 0
    end
end


----------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------

local function init()
    current = 0.0
    lastTime = getTime()
    initialized = false
end


----------------------------------------------------------------------
-- MAIN
----------------------------------------------------------------------

local function run(throttleRaw, knobRaw)

    local target = toPercent(throttleRaw)

    --------------------------------------------------------------
    -- Work out elapsed time
    --------------------------------------------------------------

    local now = getTime()

    if not initialized then
        current = target
        lastTime = now
        initialized = true
        return toEdgeTX(current)
    end

    -- getTime() uses 10 ms ticks
    local dt = (now - lastTime) / 100.0
    lastTime = now

    -- Protect against script pauses / timer wrap / unusual delays
    if dt < 0 then
        dt = 0
    elseif dt > MAX_DT then
        dt = MAX_DT
    end


    --------------------------------------------------------------
    -- Neutral cleanup
    --------------------------------------------------------------

    if math.abs(target) <= NEUTRAL_DEADBAND then
        target = 0.0
    end


    --------------------------------------------------------------
    -- Direction reversal
    --------------------------------------------------------------

    local currentSign = sign(current)
    local targetSign  = sign(target)

    if REVERSE_BYPASS
       and currentSign ~= 0
       and targetSign ~= 0
       and currentSign ~= targetSign then

        -- Driver deliberately commanded opposite direction.
        -- Treat this as braking/reverse, not coasting.
        current = target
        return toEdgeTX(current)
    end


    --------------------------------------------------------------
    -- Decide whether driver is accelerating or slowing down
    --------------------------------------------------------------

    local currentMag = math.abs(current)
    local targetMag  = math.abs(target)

    if targetMag >= currentMag then

        ----------------------------------------------------------
        -- MORE throttle -> immediate response
        ----------------------------------------------------------

        current = target

    else

        ----------------------------------------------------------
        -- LESS throttle -> exponential coast
        ----------------------------------------------------------

        local coastTime = knobToCoastTime(knobRaw)

        if coastTime <= 0.001 then
            current = target
        else
            -- Exponential decay:
            --
            -- difference(t) = difference(0) * exp(-k*t)
            --
            -- Choose k so that after "coastTime":
            --
            -- difference = EXP_REMAIN * original difference
            --
            -- Therefore:
            --
            -- k = -ln(EXP_REMAIN) / coastTime

            local k = -math.log(EXP_REMAIN) / coastTime

            local decay = math.exp(-k * dt)

            current = target + (current - target) * decay
        end
    end


    --------------------------------------------------------------
    -- Snap tiny remaining difference to target
    --------------------------------------------------------------

    if math.abs(current - target) < MIN_OUTPUT_CHANGE then
        current = target
    end


    --------------------------------------------------------------
    -- Snap to true neutral
    --------------------------------------------------------------

    if target == 0.0 and math.abs(current) <= NEUTRAL_DEADBAND then
        current = 0.0
    end


    return toEdgeTX(current)
end


----------------------------------------------------------------------
-- EDGETX INTERFACE
----------------------------------------------------------------------

local inputs = {
    { "Thr",    SOURCE },
    { "Knob",   SOURCE },
}

local outputs = {
    "Out"
}

return {
    input  = inputs,
    output = outputs,
    init   = init,
    run    = run
}
