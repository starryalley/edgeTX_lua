-- SCX30 ELRS crawler dashboard for the RadioMaster MT12 (128x64)
-- Model: SCX30 Jeep / document1.etx MODELS/model09.yml
--
-- GV1 sets throttle limit; P1 controls CH2 throttle expo in this model.
-- The expo readout is capped at +/-50; this does not limit the model itself.
-- RxBt is the receiver-reported 2S/3S pack voltage.

local W = LCD_W
local H = LCD_H
-- SMLSIZE glyphs extend one pixel above their y coordinate on the MT12.
local FOOTER_TOP = H - 10
local FOOTER_TEXT_Y = FOOTER_TOP + 1

local CELL_FULL = 4.20
local CELL_EMPTY = 3.20
-- 0 = automatic, or set 2/3 explicitly for an already deeply discharged pack.
-- Voltage alone cannot distinguish an exhausted 3S pack from a normal 2S.
local PACK_CELLS = 0
local detectedCells, missingSince, lowSince = nil, nil, nil
local batteryVoltage, batteryLow = 0, false

local function updateBattery()
  local now = getTime()
  local voltage, current = getSourceValue("RxBt")
  if not current or type(voltage) ~= "number" or voltage <= 0 then
    batteryVoltage, batteryLow, lowSince = 0, false, nil
    missingSince = missingSince or now
    -- Ignore brief telemetry dropouts; re-detect after a pack disconnect.
    if now - missingSince >= 300 then detectedCells = nil end
    return
  end
  missingSince = nil
  if PACK_CELLS == 2 or PACK_CELLS == 3 then
    detectedCells = PACK_CELLS
  elseif not detectedCells then
    detectedCells = voltage > 8.6 and 3 or 2
  elseif voltage > 8.6 then
    -- Allow a higher pack to be recognised even after a very quick swap.
    detectedCells = 3
  end
  batteryVoltage = voltage
  if voltage < detectedCells * CELL_EMPTY then
    lowSince = lowSince or now
  else
    lowSince = nil
  end
  batteryLow = getLogicalSwitchValue(7) or (lowSince ~= nil and now - lowSince >= 200)
end

-- Keep these in sync with USER SETTINGS in mixes/coast.lua.
local COAST_TIME_MIN = 0.10
local COAST_TIME_MID = 1.20
local COAST_TIME_MAX = 2.20

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

-- Centre-zero output bars, matching bounce.lua, inverted for the footer.
local function drawOutputBar(x, y, value)
  local half = 9
  local fill = math.min(half, math.floor(math.abs(value) * half / 1024 + 0.5))
  lcd.drawLine(x, y + 1, x + 2 * half, y + 1, SOLID, ERASE)
  lcd.drawLine(x + half, y, x + half, y + 2, SOLID, ERASE)
  if fill > 0 then
    lcd.drawFilledRectangle(value < 0 and x + half - fill or x + half,
      y, fill, 3, ERASE)
  end
end

local function drawBar(x, y, width, height, value, minimum, maximum)
  local fill = math.floor(clamp((value - minimum) / (maximum - minimum), 0, 1) * (width - 2) + 0.5)
  lcd.drawRectangle(x, y, width, height)
  if fill > 0 then
    lcd.drawFilledRectangle(x + 1, y + 1, fill, height - 2)
  end
end

local function drawBattery(voltage, lowBattery)
  lcd.drawText(2, 19, lowBattery and "LOW BATT" or
    (voltage > 0 and "PACK " .. detectedCells .. "S" or "PACK"),
    SMLSIZE + (lowBattery and INVERS or 0))

  if voltage <= 0 then
    lcd.drawText(3, 27, "--.-V", MIDSIZE + BLINK)
    lcd.drawText(3, 40, "NO TELEMETRY", SMLSIZE)
    drawBar(3, 48, 53, 5, CELL_EMPTY, CELL_EMPTY, CELL_FULL)
    return
  end

  local flags = MIDSIZE
  if lowBattery then flags = flags + BLINK end
  lcd.drawNumber(3, 26, math.floor(voltage * 10 + 0.5), flags + PREC1)
  lcd.drawText(lcd.getLastRightPos() + 1, 26, "V", flags)
  local cellVoltage = voltage / detectedCells
  lcd.drawNumber(4, 40, math.floor(cellVoltage * 10 + 0.5), SMLSIZE + PREC1)
  lcd.drawText(lcd.getLastRightPos() + 1, 40, "V/cell", SMLSIZE)
  drawBar(3, 48, 53, 5, cellVoltage, CELL_EMPTY, CELL_FULL)
end

local function formatHoursMinutes(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor(seconds / 60) % 60
  return string.format("%02d:%02d", hours, minutes)
end

local function formatMinutesSeconds(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  local minutes = math.floor(seconds / 60)
  local remainder = seconds % 60
  return string.format("%02d:%02d", minutes, remainder)
end

local function drawCoast()
  -- MT12 FL1 is exposed as s3, as in the other surface dashboards.
  local enabled = (getValue("s3") or 0) > 0
  local knob = clamp((getValue("s2") or 0) / 1024, -1, 1)
  local seconds
  if knob <= 0 then
    seconds = COAST_TIME_MIN + (COAST_TIME_MID - COAST_TIME_MIN) * (knob + 1)
  else
    seconds = COAST_TIME_MID + (COAST_TIME_MAX - COAST_TIME_MID) * knob
  end

  lcd.drawText(2, 11, "COAST", SMLSIZE)
  lcd.drawText(32, 11, enabled and "ON" or "OFF",
    SMLSIZE + (enabled and INVERS or 0))
  lcd.drawText(54, 11, string.format("%.2fs", seconds), SMLSIZE)
  -- Position is the selected knob setting, including when coast is off.
  drawBar(91, 11, 35, 6, knob, -1, 1)
end

local function run(event)
  lcd.clear()

  local fm, mode = getFlightMode()
  if mode == nil or mode == "" then mode = "FM" .. fm end

  -- One-line header: D = drive time (mm:ss), T = total time (hh:mm).
  lcd.drawFilledRectangle(0, 0, W, 9)
  lcd.drawText(2, 1, mode, SMLSIZE + INVERS)
  local driveTimer = model.getTimer(0)
  local totalTimer = model.getTimer(2)
  lcd.drawText(W - 1, 1,
    "D" .. formatMinutesSeconds(driveTimer and driveTimer.value)
      .. " T" .. formatHoursMinutes(totalTimer and totalTimer.value),
    RIGHT + SMLSIZE + INVERS)
  drawCoast()

  updateBattery()
  drawBattery(batteryVoltage, batteryLow)

  -- Divider and live setup values.
  lcd.drawLine(60, 19, 60, FOOTER_TOP - 1, SOLID, 0)
  local throttleMax = model.getGlobalVariable(0, fm)
  local expo = clamp(math.floor((getValue("s1") or 0) * 100 / 1024 + 0.5), -50, 50)
  local linkQuality = getValue("RQly") or 0

  lcd.drawText(64, 19, "THR MAX", SMLSIZE)
  lcd.drawNumber(W - 9, 18, throttleMax, RIGHT + MIDSIZE)
  lcd.drawText(W - 8, 21, "%", SMLSIZE)

  lcd.drawText(64, 31, "EXP (P1)", SMLSIZE)
  lcd.drawText(W - 1, 31, string.format("%d%%", expo), RIGHT + SMLSIZE)

  -- MT12 T1 = steering, T2 = throttle. Trim sources are 8 * trim units.
  -- Only steering trim is displayed, directly below expo.
  local steerTrim = math.floor((getValue("trim-ste") or 0) / 8 + 0.5)
  lcd.drawText(64, 39, "TR " .. steerTrim, SMLSIZE)

  -- FL2 is P4 (s4) on this MT12; white-on-black marks lights ON.
  local lights = (getValue("s4") or 0) > 0
  lcd.drawText(64, 47, lights and "LIT ON" or "LIT OFF",
    SMLSIZE + (lights and INVERS or 0))
  lcd.drawText(W - 1, 47, linkQuality > 0 and string.format("LQ %d", linkQuality)
    or "LQ ---", RIGHT + SMLSIZE)

  -- Footer: live controls and clock.
  lcd.drawFilledRectangle(0, FOOTER_TOP, W, H - FOOTER_TOP)
  local throttle = getValue("ch2") or 0
  local steering = getValue("ch1") or 0
  lcd.drawText(2, FOOTER_TEXT_Y, "S", SMLSIZE + INVERS)
  drawOutputBar(8, FOOTER_TOP + 4, steering)
  lcd.drawText(46, FOOTER_TEXT_Y, tostring(math.floor(steering * 100 / 1024 + 0.5)),
    RIGHT + SMLSIZE + INVERS)
  lcd.drawText(48, FOOTER_TEXT_Y, "T", SMLSIZE + INVERS)
  drawOutputBar(54, FOOTER_TOP + 4, throttle)
  lcd.drawText(92, FOOTER_TEXT_Y, tostring(math.floor(throttle * 100 / 1024 + 0.5)),
    RIGHT + SMLSIZE + INVERS)
  local now = getDateTime()
  lcd.drawText(W - 1, FOOTER_TEXT_Y, string.format("%02d:%02d", now.hour, now.min),
    RIGHT + SMLSIZE + INVERS)

  return 0
end

local function init()
  detectedCells, missingSince, lowSince = nil, nil, nil
  batteryVoltage, batteryLow = 0, false
end

return { run = run, init = init, background = updateBattery }
