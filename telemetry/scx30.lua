-- SCX30 ELRS crawler dashboard for the RadioMaster MT12 (128x64)
-- Model: SCX30 ELRS / model08.yml
--
-- The model uses GV1 as the throttle limit for each drive mode and L6 as
-- the 40% steering-expo toggle. RxBt is the receiver-reported 2S pack.

local W = LCD_W
local H = LCD_H
-- SMLSIZE glyphs extend one pixel above their y coordinate on the MT12.
local FOOTER_TOP = H - 10
local FOOTER_TEXT_Y = FOOTER_TOP + 1

local PACK_FULL = 8.40
local PACK_EMPTY = 6.40
local LOW_PACK = 6.60

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function percent(value)
  return math.floor(value * 100 / 1024 + (value >= 0 and 0.5 or -0.5))
end

local function drawBar(x, y, width, height, value, minimum, maximum)
  local fill = math.floor(clamp((value - minimum) / (maximum - minimum), 0, 1) * (width - 2) + 0.5)
  lcd.drawRectangle(x, y, width, height)
  if fill > 0 then
    lcd.drawFilledRectangle(x + 1, y + 1, fill, height - 2)
  end
end

local function drawBattery(voltage, blink)
  lcd.drawText(2, 19, "PACK", SMLSIZE)

  if voltage <= 0 then
    lcd.drawText(3, 27, "--.-V", MIDSIZE + BLINK)
    lcd.drawText(3, 40, "NO TELEMETRY", SMLSIZE)
    drawBar(3, 48, 53, 5, PACK_EMPTY, PACK_EMPTY, PACK_FULL)
    return
  end

  local flags = MIDSIZE
  if voltage <= LOW_PACK and blink then flags = flags + BLINK end
  lcd.drawNumber(3, 26, math.floor(voltage * 10 + 0.5), flags + PREC1)
  lcd.drawText(lcd.getLastRightPos() + 1, 26, "V", flags)
  lcd.drawNumber(4, 40, math.floor(voltage * 5 + 0.5), SMLSIZE + PREC1)
  lcd.drawText(lcd.getLastRightPos() + 1, 40, "V/cell", SMLSIZE)
  drawBar(3, 48, 53, 5, voltage, PACK_EMPTY, PACK_FULL)
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

local function drawSignalBars(x, bottom, quality)
  for i = 1, 4 do
    local height = i * 2 + 1
    local top = bottom - height + 1
    lcd.drawRectangle(x + (i - 1) * 5, top, 3, height)
    if quality >= (i - 1) * 25 + 1 then
      lcd.drawFilledRectangle(x + (i - 1) * 5 + 1, top + 1, 1, height - 2)
    end
  end
end

local function run(event)
  lcd.clear()

  local fm, mode = getFlightMode()
  if mode == nil or mode == "" then mode = "FM" .. fm end

  -- Header: the active drive mode is the most important crawler setting.
  lcd.drawFilledRectangle(0, 0, W, 17)
  lcd.drawText(3, 0, mode, DBLSIZE + INVERS)
  local driveTimer = model.getTimer(0)
  local totalTimer = model.getTimer(2)
  lcd.drawText(W - 1, 0, "TMD " .. formatMinutesSeconds(driveTimer and driveTimer.value),
    RIGHT + SMLSIZE + INVERS)
  lcd.drawText(W - 1, 8, "TOT " .. formatHoursMinutes(totalTimer and totalTimer.value),
    RIGHT + SMLSIZE + INVERS)

  -- Left panel: receiver-reported 2S battery.
  local rxBattery = getValue("RxBt") or 0
  drawBattery(rxBattery, (getTime() % 100) < 50)

  -- Divider and live setup values.
  lcd.drawLine(60, 19, 60, FOOTER_TOP - 1, SOLID, 0)
  local throttleMax = model.getGlobalVariable(0, fm)
  local expoOn = getLogicalSwitchValue(5) -- L6: 40% steering expo mix
  local steerExpo = expoOn and 40 or 0
  local linkQuality = getValue("RQly") or 0

  lcd.drawText(64, 19, "THR MAX", SMLSIZE)
  lcd.drawNumber(W - 9, 18, throttleMax, RIGHT + MIDSIZE)
  lcd.drawText(W - 8, 21, "%", SMLSIZE)

  lcd.drawText(64, 31, "STE EXPO", SMLSIZE)
  lcd.drawNumber(W - 9, 30, steerExpo, RIGHT + MIDSIZE)
  lcd.drawText(W - 8, 33, "%", SMLSIZE)

  lcd.drawText(64, 43, "LQ", SMLSIZE)
  if linkQuality > 0 then
    lcd.drawNumber(105, 42, linkQuality, RIGHT + MIDSIZE)
  else
    lcd.drawText(105, 42, "---", RIGHT + MIDSIZE)
  end
  drawSignalBars(109, FOOTER_TOP - 1, linkQuality)

  -- Footer: live controls and useful neutral references.
  lcd.drawFilledRectangle(0, FOOTER_TOP, W, H - FOOTER_TOP)
  local throttle = percent(getValue("thr") or 0)
  local steering = percent(getValue("ste") or 0)
  local steerTrim = math.floor((getValue("trim-ste") or 0) * 100 / 1024 + 0.5)
  lcd.drawText(2, FOOTER_TEXT_Y, "T", SMLSIZE + INVERS)
  lcd.drawNumber(10, FOOTER_TEXT_Y, throttle, SMLSIZE + INVERS)
  lcd.drawText(37, FOOTER_TEXT_Y, "S", SMLSIZE + INVERS)
  lcd.drawNumber(45, FOOTER_TEXT_Y, steering, SMLSIZE + INVERS)
  lcd.drawText(72, FOOTER_TEXT_Y, "TRIM", SMLSIZE + INVERS)
  lcd.drawNumber(W - 2, FOOTER_TEXT_Y, steerTrim, RIGHT + SMLSIZE + INVERS)

  return 0
end

local function init()
end

return { run = run, init = init }
