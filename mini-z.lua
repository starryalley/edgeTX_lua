-------------------------
-- based on https://www.rctech.net/forum/showpost.php?p=16138355&postcount=528
-- For my mini-z RWD/AWD
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
end

--FUNCTION: draw Timer1
local function drawTimer1(blinkCount)
  local timer1Value = model.getTimer(0).value
  local timer1Name = model.getTimer(0).name
  if math.abs(timer1Value) > 60 * 60 then
    timer1Value = timer1Value / 60
  end
  if timer1Value < 0 then
    lcd.drawTimer(124, 2 * FH, timer1Value, RIGHT + DBLSIZE + BLINK + INVERS)
    lcd.drawText(69, 3 * FH, timer1Name, RIGHT)
  else
    lcd.drawTimer(124, 2 * FH, timer1Value, RIGHT + DBLSIZE)
    lcd.drawText(76, 3 * FH, timer1Name, RIGHT)
    if blinkCount < 50 and getLogicalSwitchValue(0) then
      lcd.drawText(96, 2 * FH, " ", DBLSIZE)
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
local function drawStick(centrex, xval, yval)
  local BOX_CENTERY = (LCD_H - 9 - (BOX_WIDTH-1) / 2)
  lcd.drawRectangle(centrex - (BOX_WIDTH-1) / 2, BOX_CENTERY - (BOX_WIDTH-1) / 2, BOX_WIDTH , BOX_WIDTH)
  lcd.drawLine(centrex, BOX_CENTERY + 1, centrex, BOX_CENTERY - 1, SOLID, 0)
  lcd.drawLine(centrex - 1, BOX_CENTERY, centrex + 1, BOX_CENTERY, SOLID, 0)
  xval = centrex + math.floor(xval / 2048 * (BOX_WIDTH - 5) + 0.5)
  yval = BOX_CENTERY - math.floor(yval / 2048 * (BOX_WIDTH - 5) + 0.5)
  lcd.drawFilledRectangle(xval - 2, yval - 1, 5, 3)
  lcd.drawFilledRectangle(xval - 1, yval - 2, 3, 5)
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

-- FUNCTION: draw GVARs
local function drawGvars()
  local strRate = getValue("gvar1") -- steering dual rate
  local thrRate = getValue("gvar2")  -- throttle dual rate
  local dbRate = math.floor(getValue("trim-t3") * 128 / 1049 + 0.5)  -- drag brake strength
  local strExpo = getValue("gvar3") -- steering expo
  local thrExpo = getValue("gvar4") -- throttle expo
  
  lcd.drawFilledRectangle(16, LCD_H - 23 , 16, 15)
  lcd.drawFilledRectangle(LCD_W - 17, LCD_H - 23 , 17, 15)

  -- upper right
  lcd.drawText(16*FW, LCD_H - 22 , "StR", SMLSIZE)
  -- upper left, lower left
  if getLogicalSwitchValue(7) then -- L08 on means Drag brake is ON
    lcd.drawText(0, LCD_H - 29 , "DbR", SMLSIZE)
  else
    lcd.drawText(2, LCD_H - 29 , "NoDrag", SMLSIZE + INVERS)
  end
  lcd.drawText(FW, LCD_H - 15 , "St", SMLSIZE)
  lcd.drawText(FW, LCD_H - 22 , "Th", SMLSIZE)
  lcd.drawText(FW, LCD_H - 15 , CHAR_CYC, RIGHT + INVERS)
  lcd.drawText(FW, LCD_H - 22 , CHAR_CYC, RIGHT + INVERS)

  -- lower right
  lcd.drawText(16*FW + 1, LCD_H - 15 , "ThR", SMLSIZE)

  -- value for upper right
  lcd.drawNumber(LCD_W, LCD_H - 22 , strRate, SMLSIZE + RIGHT + INVERS)
  -- value for upper left and lower left
  if getLogicalSwitchValue(7) then -- L08 on means Drag brake is ON
    lcd.drawNumber(5*FW + 2, LCD_H - 29 , dbRate, SMLSIZE + RIGHT + INVERS)
  end
  lcd.drawNumber(5*FW + 2, LCD_H - 15 , strExpo, SMLSIZE + RIGHT + INVERS)
  lcd.drawNumber(5*FW + 2, LCD_H - 22 , thrExpo, SMLSIZE + RIGHT + INVERS)
  -- value for lower right
  lcd.drawNumber(LCD_W, LCD_H - 15 , thrRate, SMLSIZE + RIGHT + INVERS)
end


local function run()
  local blinkCount = getTime() % 100
  lcd.clear()
  modelName = model.getInfo().name
  lcd.drawText(MODELNAME_X, MODELNAME_Y, modelName, DBLSIZE)
  
  displayBattVoltage(blinkCount)
  drawFM()
  drawAntenna()
  drawTimer1(blinkCount)
  drawTimer3()
  
--drawSwitchSymbol (3*FW - 6, 33, "A", getValue("sa"))
  drawSwitchSymbol (PHASE_X+1, PHASE_Y+FH, "A", getValue("sa"))
--drawSwitchSymbol (18*FW - 8, 33, "B", getValue("sb"))
  drawStick(RBOX_CENTERX, getValue("ste"), 0)
  drawStick(LBOX_CENTERX, 0, getValue("thr"))
  drawPotsBars()
  displayTrims()
  drawRTC(blinkCount)

  drawGvars()
end

local function init()
end

return { run=run, init=init  }
  