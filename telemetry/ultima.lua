-------------------------
-- based on https://www.rctech.net/forum/showpost.php?p=16138355&postcount=528
-- For my RC cars (mini-z AWD/RWD/Buggy, 1/10 touring car and race buggy)
-- probably not for crawlers
------- CONSTANTS -------
local BOX_WIDTH = 23
local FW = 6
local FH = 8
--local LCD_W = 128
--local LCD_H = 64
local LBOX_CENTERX = LCD_W/4 + 12   --10
local RBOX_CENTERX = 3*LCD_W/4 - 13 --10
local MODELNAME_X = 2*FW-2
local MODELNAME_Y = 0
local PHASE_X     = 6*FW-2
local PHASE_Y     = 2*FH
local PHASE_FLAGS = 0
local VBATT_X     = 6*FW-1
local VBATT_Y     = 2*FH
local VBATTUNIT_Y = 3*FH
local REBOOT_X    = 2
local BAR_HEIGHT  = BOX_WIDTH-1
local TRIM_LEN    = 17
local TRIM_LH_X   = TRIM_LEN+6
local TRIM_LV_X   = 3
local TRIM_RV_X   = LCD_W-4
local TRIM_RH_X   = LCD_W-TRIM_LEN-7
local TRIM_LH_NEG = TRIM_LH_X+TRIM_LEN+1 -- +3*FW+1
local TRIM_LH_POS = TRIM_LH_X-TRIM_LEN   -- -4*FW+3
local TRIM_RH_NEG = TRIM_RH_X+TRIM_LEN+1 -- +3*FW+1
local TRIM_RH_POS = TRIM_RH_X-TRIM_LEN   -- -4*FW+3
local RSSSI_X     = 30
local RSSSI_Y     = 31
local RSSI_MAX    = 105
local CLOCK_X     = 53
local CLOCK_Y     = 57
local battMax     = 8.4
local battMin     = 6.6
local modelName   = ""
-------------------------

--FUNCTION: draw Battey Voltage
local function displayBattVoltage(blinkCount)
  local txBatt = getValue("tx-voltage")
  local battCount = (txBatt - battMin) / (battMax - battMin) * 20
  lcd.drawFilledRectangle(VBATT_X - 26, VBATT_Y, 24, 15)
  lcd.drawNumber(VBATT_X - 8, VBATT_Y + 1, txBatt * 10, PREC1 + RIGHT + INVERS)
  lcd.drawText(VBATT_X - 8, VBATT_Y + 1, "V", INVERS)
  lcd.drawFilledRectangle(VBATT_X - 25, VBATT_Y + 9, 21, 5)
  lcd.drawLine(VBATT_X - 4, VBATT_Y + 10, VBATT_X - 4, VBATT_Y + 12, SOLID, ERASE)
  for i = 0, math.min(battCount, 18), 2 do 
    if (blinkCount < 50) or (battCount > 3) then
      lcd.drawLine(VBATT_X - 24 + i, VBATT_Y + 10, VBATT_X - 24 + i, VBATT_Y + 12, SOLID, 0)
    end
  end
end

--FUNCTION: drawFM Display flight mode
local function drawFM()
	local fmno, fmname = getFlightMode()
	if fmname == "" then
		fmname = "FM".. fmno
	end
	lcd.drawText(PHASE_X, PHASE_Y, fmname, 0)
end

--FUNCTION: draw Antenna and RSSI
local function drawAntenna()
  local rssiValue, alarmLow, alarmCrit = getRSSI()
  for i = 1, 4, 1 do
    if (rssiValue - alarmLow) > ((RSSI_MAX - alarmLow) / 4 * (i - 1)) then
      lcd.drawFilledRectangle(RSSSI_X + i * 4, RSSSI_Y - 2 * i + 1, 3, 2 * i - 1)
    end
  end
  return rssiValue
end

--FUNCTION: draw Timer1
local function drawTimer1(blinkCount, showName)
  local timer1Value = model.getTimer(0).value
  local timer1Name = model.getTimer(0).name
  if math.abs(timer1Value) > 60 * 60 then
    timer1Value = timer1Value / 60
  end
  if timer1Value < 0 then
    lcd.drawTimer(124, 2 * FH, timer1Value, RIGHT + DBLSIZE + BLINK + INVERS)
    if showName then
      lcd.drawText(69, 3 * FH, timer1Name, RIGHT)
    end
  else
    lcd.drawTimer(124, 2 * FH, timer1Value, RIGHT + DBLSIZE)
    if showName then
      lcd.drawText(76, 3 * FH, timer1Name, RIGHT)
    end
    if blinkCount < 50 then
      lcd.drawText(95, 2 * FH, " ", DBLSIZE)
    end
  end
end

local function drawTimer3()
  local timer3Value = model.getTimer(2).value
  if math.abs(timer3Value) > 60 * 60 then
    timer3Value = timer3Value / 60
  end
  if timer3Value < 0 then
    lcd.drawTimer(22*FW, LCD_H - 30, timer3Value, RIGHT + SMLSIZE + BLINK + INVERS)
  else
    lcd.drawTimer(22*FW, LCD_H - 30, timer3Value, RIGHT + SMLSIZE)
  end
  --lcd.drawText(16*FW, LCD_H - 29 , "TIMER", SMLSIZE)
end

--FUNCTUON: draw Stick
local function drawStickAir(centrex, xval, yval)
  local BOX_CENTERY = (LCD_H - 9 - (BOX_WIDTH-1) / 2)
  lcd.drawRectangle(centrex - (BOX_WIDTH-1) / 2, BOX_CENTERY - (BOX_WIDTH-1) / 2, BOX_WIDTH , BOX_WIDTH)
  lcd.drawLine(centrex, BOX_CENTERY + 1, centrex, BOX_CENTERY - 1, SOLID, 0)
  lcd.drawLine(centrex - 1, BOX_CENTERY, centrex + 1, BOX_CENTERY, SOLID, 0)
  xval = centrex + math.floor(xval / 2048 * (BOX_WIDTH - 5) + 0.5)
  yval = BOX_CENTERY - math.floor(yval / 2048 * (BOX_WIDTH - 5) + 0.5)
  lcd.drawFilledRectangle(xval - 2, yval - 1, 5, 3)
  lcd.drawFilledRectangle(xval - 1, yval - 2, 3, 5)
end

local function drawStickSurfaceThrottle(centrex, val)
  local BOX_CENTERY = (LCD_H - 9 - (BOX_WIDTH-1) / 2)
  lcd.drawRectangle(centrex - (BOX_WIDTH-1) / 2, BOX_CENTERY - (BOX_WIDTH-1) / 2, BOX_WIDTH , BOX_WIDTH)
  
  xval = math.floor(val / 2048 * (BOX_WIDTH/2) + 0.5)
  if xval ~= 0 then
    lcd.drawLine(centrex - xval, BOX_CENTERY, centrex, BOX_CENTERY - xval, SOLID, 0)
    lcd.drawLine(centrex + xval, BOX_CENTERY, centrex, BOX_CENTERY - xval, SOLID, 0)
    lcd.drawPoint(centrex, BOX_CENTERY - xval)
  end
  -- horizontal base line that doesn't change
  lcd.drawLine(centrex - BOX_WIDTH/4, BOX_CENTERY, centrex + BOX_WIDTH/4, BOX_CENTERY, SOLID, 0)
end

local function drawStickSurfaceSteer(centrex, val)
  local BOX_CENTERY = (LCD_H - 9 - (BOX_WIDTH-1) / 2)
  lcd.drawRectangle(centrex - (BOX_WIDTH-1) / 2, BOX_CENTERY - (BOX_WIDTH-1) / 2, BOX_WIDTH , BOX_WIDTH)
  
  yval = math.floor(val / 2048 * (BOX_WIDTH/4) + 0.5)
  lcd.drawLine(centrex-BOX_WIDTH/4+yval, BOX_CENTERY-BOX_WIDTH/6, centrex-BOX_WIDTH/4-yval, BOX_CENTERY+BOX_WIDTH/6, SOLID, 0)
  lcd.drawLine(centrex+BOX_WIDTH/4+yval, BOX_CENTERY-BOX_WIDTH/6, centrex+BOX_WIDTH/4-yval, BOX_CENTERY+BOX_WIDTH/6, SOLID, 0)
  -- horizontal base line that doesn't change
  lcd.drawLine(centrex - BOX_WIDTH/8, BOX_CENTERY, centrex + BOX_WIDTH/8, BOX_CENTERY, SOLID, 0)
end

--FUNCTION: draw Pot Bars
local function drawPotsBars()
  local len = math.floor((getValue("s1") + 1024) / 2048 * BAR_HEIGHT + 1)
  lcd.drawFilledRectangle(LCD_W / 2 + 1, LCD_H - 8 - len, 3, len)
  len = math.floor((getValue("s2") + 1024) / 2048 * BAR_HEIGHT + 1)
  lcd.drawFilledRectangle(LCD_W / 2 - 4, LCD_H - 8 - len, 3, len)
end

--FUNCTION: draw Trims
local function displayTrims()
  local x = {TRIM_LH_X, TRIM_RH_X, TRIM_RV_X, TRIM_LV_X, TRIM_LV_X}
  local vert = {60, 60, TRIM_LEN + 3, TRIM_LEN + 3, TRIM_LEN + 3}
  local idTrim = {"trim-ste", "trim-thr", "trim-t3", "trim-t4", "trim-t5"}
  local modeTrim = {"sqr", "sqr", "main", "main", "sub"}--sqr,main,sub,none
  for i = 1, 5, 1 do
    local xm = x[i]
    local ym = vert[i]
    local val = math.floor(getValue(idTrim[i]) * 128 / 1049 + 0.5)
    local dir = math.floor(val * TRIM_LEN / 128 + 0.5)
    if dir > TRIM_LEN then
      dir = TRIM_LEN
    end
    if dir < -TRIM_LEN then
      dir = -TRIM_LEN
    end
    
    if vert[i] == TRIM_LEN + 3 then
      if i < 5 then
        lcd.drawLine(xm, ym - TRIM_LEN, xm, ym + TRIM_LEN, SOLID, 0)
        if modeTrim[i] == "sqr" then
          lcd.drawFilledRectangle(xm - 1, ym - 1, 3, 3, FORCE)
        end
      end
      ym = ym - dir
      if modeTrim[i] == "sqr" then
        lcd.drawFilledRectangle(xm - 2, ym - 3, 5, 7, FORCE)
        lcd.drawFilledRectangle(xm - 3, ym - 2, 7, 5)
        if val >= 0 then
          lcd.drawLine(xm - 1, ym - 1, xm + 1, ym - 1, SOLID, 0)
        end
        if val <= 0 then
          lcd.drawLine(xm - 1, ym + 1, xm + 1, ym + 1, SOLID, 0)
        end
      elseif modeTrim[i] == "sub" then
        lcd.drawLine(xm - 1, ym, xm - 1, ym, SOLID, 0)
        lcd.drawLine(xm - 2, ym - 1, xm - 2, ym + 1, SOLID, 0)
        lcd.drawLine(xm - 3, ym - 2, xm - 3, ym + 2, SOLID, 0)
      elseif modeTrim[i] == "main" then
        lcd.drawLine(xm + 1, ym, xm + 1, ym, SOLID, 0)
        lcd.drawLine(xm + 2, ym - 1, xm + 2, ym + 1, SOLID, 0)
        lcd.drawLine(xm + 3, ym - 2, xm + 3, ym + 2, SOLID, 0)
      end
    
    else
      if i < 5 then
        lcd.drawLine(xm - TRIM_LEN, ym, xm + TRIM_LEN, ym, SOLID, 0)
        if modeTrim[i] == "sqr" then
          lcd.drawFilledRectangle(xm - 1, ym - 1, 3, 3, FORCE)
        end
      end
      xm = xm + dir
      if modeTrim[i] == "sqr" then
        lcd.drawFilledRectangle(xm - 3, ym - 2, 7, 5, FORCE)
        lcd.drawFilledRectangle(xm - 2, ym - 3, 5, 7)
        if val >= 0 then
          lcd.drawLine(xm + 1, ym - 1, xm + 1, ym + 1, SOLID, 0)
        end
        if val <= 0 then
          lcd.drawLine(xm - 1, ym - 1, xm - 1, ym + 1, SOLID, 0)
        end
      elseif modeTrim[i] == "main" then
        lcd.drawLine(xm, ym - 1, xm, ym - 1, SOLID, 0)
        lcd.drawLine(xm - 1, ym - 2, xm + 1, ym - 2, SOLID, 0)
        lcd.drawLine(xm - 2, ym - 3, xm + 2, ym - 3, SOLID, 0)
      elseif modeTrim[i] == "sub" then
        lcd.drawLine(xm, ym + 1, xm, ym + 1, SOLID, 0)
        lcd.drawLine(xm - 1, ym + 2, xm + 1, ym + 2, SOLID, 0)
        lcd.drawLine(xm - 2, ym + 3, xm + 2, ym + 3, SOLID, 0)
      end
      if val > 0 then
        if xm > LCD_W / 2 then
          lcd.drawNumber(TRIM_RH_POS-5, ym-3, val, SMLSIZE)
        else
          lcd.drawNumber(TRIM_LH_POS-5, ym-3, val, SMLSIZE)
        end
      elseif val < 0 then
        if xm > LCD_W / 2 then
          lcd.drawNumber(TRIM_RH_NEG+6, ym-3, val, SMLSIZE + RIGHT)
          lcd.drawPoint(lcd.getLastLeftPos(), ym)
        else
          lcd.drawNumber(TRIM_LH_NEG+6, ym-3, val, SMLSIZE + RIGHT)
          lcd.drawPoint(lcd.getLastLeftPos(), ym)
        end
      end
    end
  end
end

--FUNCTION: draw SwitchSymbol, up/middle/down
local function drawSwitchSymbol(x,y,sw,val)
	if val < 0 then
		lcd.drawText(x, y, "S"..sw..CHAR_UP, BLINK)--SMLSIZE)
	elseif val == 0 then
		lcd.drawText(x, y, "S"..sw.."-", 0)--SMLSIZE)
	else
		lcd.drawText(x, y, "S"..sw..CHAR_DOWN, INVERS)--SMLSIZE)
	end
end

-- FUNCTION: draw Real Time Clock
local function drawRTC(blinkCount)
  local tableRtc = getDateTime()
  local timeRtc = tableRtc.hour * 60 + tableRtc.min
  lcd.drawTimer(CLOCK_X, CLOCK_Y, timeRtc, 0)
  if (blinkCount < 20) then
    lcd.drawText (CLOCK_X + 10, CLOCK_Y, " ", 0)
	end
end

local function drawCycleAndDuty(x, y, cycle, duty)
  if cycle >= 1000 then
    -- as seconds
    lcd.drawNumber(x, y, cycle/10, PREC2+SMLSIZE + RIGHT)
  else
    -- as milliseconds
    lcd.drawNumber(x, y, cycle, SMLSIZE + RIGHT)
  end
  -- duty cycle as 0~100% filled rectangle of max width 3*FW+1
  if duty > 0 then
    local offset = math.floor(duty * (3*FW+1) / 100 + 0.5)
    lcd.drawFilledRectangle(x-(3*FW), y-1, offset, FH+2)
  end
end

-- FUNCTION: draw GVARs
local function drawGvars()
  local strRate = getValue("gvar1") -- steering rate
  local thrRate = getValue("gvar2")  -- throttle rate
  local strExpo = getValue("gvar3") -- steering expo
  local thrExpo = getValue("gvar4") -- throttle expo
  --local dbRate = math.floor(getValue("trim-t3") * 128 / 1049 + 0.5)  -- drag brake strength
  local dbRate = getValue("gvar5") -- drag brake strength
  local absCycleT = getValue("gvar6") -- ABS cycle time (ms)
  local absDutyC = getValue("gvar7") -- ABS duty cycle (%)
  local tcCycleT = getValue("gvar8") -- TC cycle time (ms)
  local tcDutyC = getValue("gvar9") -- TC duty cycle (%)

  -- old, not used
  --lcd.drawFilledRectangle(16, LCD_H - 23 , 16, 15)
  --lcd.drawFilledRectangle(LCD_W - 17, LCD_H - 23 , 17, 15)

  ------ Lower Left INFO (below TX battery) -------
  -- DM0: (default) track mode (SA down)
  -- FL1 on (down, or right): Drag brake, FL2 on -> ABS, L02 (SD sticky) -> TC

  local drag_brake = getLogicalSwitchValue(23) --L24
  local abs = getLogicalSwitchValue(25) --L26
  local traction_control = getLogicalSwitchValue(21) --L22

  if drag_brake then
    lcd.drawText(0, LCD_H - 29 , "DgB", SMLSIZE)
    lcd.drawNumber(5*FW + 2, LCD_H - 29 , dbRate, SMLSIZE + RIGHT + INVERS)
  else
    lcd.drawText(0, LCD_H - 29 , "DgB Off", SMLSIZE)
  end
  if abs then
    lcd.drawText(0, LCD_H - 22 , "ABS", SMLSIZE)
    drawCycleAndDuty(5*FW + 2, LCD_H - 22, absCycleT, absDutyC)
  else
    lcd.drawText(0, LCD_H - 22 , "ABS Off", SMLSIZE)
  end
  if traction_control then
    lcd.drawText(1, LCD_H - 15 , "TrC", SMLSIZE)
    drawCycleAndDuty(5*FW + 2, LCD_H - 15, tcCycleT, tcDutyC)
  else 
    lcd.drawText(1, LCD_H - 15 , "TrC Off", SMLSIZE)
  end


  ------ Lower Right INFO (below second timer) -------
  -- value for upper right (steering rate/expo)
  lcd.drawNumber(LCD_W-3*FW, LCD_H - 22 , strRate, SMLSIZE + RIGHT + INVERS)
  -- number length is just 2, so let's so expo symbol (using CHAR_CYC)
  if strExpo > -10 and strExpo < 100 then
    lcd.drawText(LCD_W-3*FW+1, LCD_H - 22 , CHAR_CYC, 0)
  end
  lcd.drawNumber(LCD_W, LCD_H - 22 , strExpo, SMLSIZE + RIGHT + INVERS)
  
  -- value for lower right (throttle rate/expo)
  lcd.drawNumber(LCD_W-3*FW, LCD_H - 15 , thrRate, SMLSIZE + RIGHT + INVERS)
  -- number length is just 2, so let's so expo symbol (using CHAR_CYC)
  if thrExpo > -10 and thrExpo < 100 then
    lcd.drawText(LCD_W-3*FW+1, LCD_H - 15 , CHAR_CYC, 0)
  end
  lcd.drawNumber(LCD_W, LCD_H - 15 , thrExpo, SMLSIZE + RIGHT + INVERS)
end


local function run()
  local blinkCount = getTime() % 100
  lcd.clear()
  modelName = model.getInfo().name
  lcd.drawText(MODELNAME_X, MODELNAME_Y, modelName, DBLSIZE)
  
  displayBattVoltage(blinkCount)
  drawFM()
  local rssi = drawAntenna()

  
--drawSwitchSymbol (3*FW - 6, 33, "A", getValue("sa"))
  if rssi > 0 then
    drawSwitchSymbol (PHASE_X+FW*3, PHASE_Y+FH, "A", getValue("sa"))
    drawTimer1(blinkCount, false)
  else
    drawSwitchSymbol (PHASE_X, PHASE_Y+FH, "A", getValue("sa"))
    drawTimer1(blinkCount, true)
  end
  drawTimer3()

--drawSwitchSymbol (18*FW - 8, 33, "B", getValue("sb"))
  drawStickSurfaceSteer(RBOX_CENTERX, getValue("ste"))
  drawStickSurfaceThrottle(LBOX_CENTERX, getValue("thr"))
  drawPotsBars()
  displayTrims()
  drawRTC(blinkCount)

  drawGvars()
end

local function init()
end

return { run=run, init=init  }
  