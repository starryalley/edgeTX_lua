-- Titan 30 / MT12 (128x64): live transmitted outputs, no receiver telemetry.
-- Signed CH1/CH2 percentages include rates, curves, trim and coasting.
-- Drag brake is a CH3 command estimate, not ESC feedback. T3 adjusts GV3.
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

-- Centre-zero bars show actual channel commands; endpoint overtravel keeps its number.
local function drawLiveOutput(y, label, source)
  local value = getValue(source) or 0
  local percent = math.floor(value * 100 / 1024 + 0.5)
  lcd.drawText(2, y, label, SMLSIZE)
  lcd.drawText(W - 2, y - 1, string.format("%+d%%", percent), RIGHT + MIDSIZE)
  local x, top, width, height = 3, y + 12, 122, 4
  local centre, half = x + 61, 60
  lcd.drawRectangle(x, top, width, height)
  local fill = math.floor(clamp(math.abs(value) / 1024, 0, 1) * half + 0.5)
  if fill > 0 then
    lcd.drawFilledRectangle(value < 0 and centre - fill or centre, top + 1, fill, height - 2)
  end
  lcd.drawLine(centre, top - 1, centre, top + height, SOLID, 0)
end

local function run(event)
  lcd.clear()
  local fm, mode = getFlightMode()
  if mode == nil or mode == "" then mode = "FM" .. fm end
  lcd.drawFilledRectangle(0, 0, W, 9)
  lcd.drawText(2, 1, mode, SMLSIZE + INVERS)
  local drive, total = model.getTimer(0), model.getTimer(2)
  lcd.drawText(W - 1, 1, "D" .. formatMinutesSeconds(drive and drive.value)
    .. " T" .. formatHoursMinutes(total and total.value), RIGHT + SMLSIZE + INVERS)
  drawCoast()
  local expo = model.getGlobalVariable(1, fm)
  drawLiveOutput(19, "ST / E(P1) " .. expo .. "%", "ch1")
  drawLiveOutput(37, "TH MAX " .. model.getGlobalVariable(0, fm) .. "%", "ch2")
  -- Show the native stored setting even if the mixer is unavailable.
  local selected = clamp(model.getGlobalVariable(2, 0), 1, 10)
  lcd.drawFilledRectangle(0, FOOTER_TOP, W, H - FOOTER_TOP)
  lcd.drawText(2, FOOTER_TEXT_Y, "DB " .. selected .. "/10", SMLSIZE + INVERS)
  for i = 1, 10 do
    local x = 45 + (i - 1) * 4
    lcd.drawRectangle(x, FOOTER_TOP + 2, 3, 6, ERASE)
    if i <= selected then lcd.drawFilledRectangle(x + 1, FOOTER_TOP + 3, 1, 4, ERASE) end
  end
  local now = getDateTime()
  lcd.drawText(W - 1, FOOTER_TEXT_Y, string.format("%02d:%02d", now.hour, now.min),
    RIGHT + SMLSIZE + INVERS)
  return 0
end

return { run = run }
