-- SCX24 GoupRC dashboard for the RadioMaster MT12 (128x64)
-- GV1 sets throttle limit; both normal/coast mixes use the preserved T1.
-- All values come from the transmitter; this receiver has no telemetry.

local W = LCD_W
local H = LCD_H
-- SMLSIZE glyphs extend one pixel above their y coordinate on the MT12.
local FOOTER_TOP = H - 10
local FOOTER_TEXT_Y = FOOTER_TOP + 1

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

  -- CH2 is the command sent to the ESC, not measured motor speed.
  local throttle = getValue("ch2") or 0
  local steering = getValue("ch1") or 0
  local trigger = getValue("thr") or 0
  lcd.drawText(2, 19, "THR OUT %", SMLSIZE)
  -- Tenths help locate the GoupRC deadband and speed transition.
  lcd.drawNumber(57, 27, math.floor(throttle * 1000 / 1024 + 0.5),
    RIGHT + MIDSIZE + PREC1)
  lcd.drawText(2, 40, "CURVE T1", SMLSIZE)
  lcd.drawText(2, 48, string.format("IN %d%%",
    math.floor(trigger * 100 / 1024 + 0.5)), SMLSIZE)

  lcd.drawLine(60, 19, 60, FOOTER_TOP - 1, SOLID, 0)
  local throttleMax = model.getGlobalVariable(0, fm)
  lcd.drawText(64, 19, "THR MAX %", SMLSIZE)
  lcd.drawNumber(W - 2, 27, throttleMax, RIGHT + MIDSIZE)

  -- MT12 T1 = steering, T2 = throttle. Trim sources are 8 * trim units.
  local steerTrim = math.floor((getValue("trim-ste") or 0) / 8 + 0.5)
  lcd.drawText(64, 40, "TR " .. steerTrim, SMLSIZE)
  local txVoltage = getValue("tx-voltage") or 0
  lcd.drawText(64, 48, txVoltage > 0 and string.format("TX %.1fV", txVoltage)
    or "TX --.-V", SMLSIZE)

  -- Footer: live controls and clock.
  lcd.drawFilledRectangle(0, FOOTER_TOP, W, H - FOOTER_TOP)
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
end

return { run = run, init = init }
