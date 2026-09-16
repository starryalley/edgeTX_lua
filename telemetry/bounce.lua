-- Bouncer dashboard, EdgeTX 2.12 / RadioMaster MT12 128x64.
-- Read-only: all driving logic lives in the model and optional bcoast mixer.
-- L2 independent; L5 Trail coast. GV2 limit, GV3 expo, GV5 coast in tenths.
local ids = {}
local function init()
  for _, name in ipairs({'RxBt', 'RQly', '1RSS', 'tx-voltage', 'ch1', 'ch2', 'ch3', 's1'}) do
    local info = getFieldInfo(name)
    ids[name] = info and info.id or name
  end
end
local function value(name)
  local v = getValue(ids[name] or name)
  return type(v) == 'number' and v or 0
end
local function sensor(name)
  local v, current = getSourceValue(ids[name] or name)
  if current and type(v) == 'number' then return v end
  return nil
end
local function pct(v)
  return math.floor(v*100/1024+0.5)
end
local function text(x,y,s,flags)
  lcd.drawText(x,y,s,SMLSIZE+(flags or 0))
end
local function timer(index, total)
  local t = model.getTimer(index)
  local seconds = math.max(0, math.floor(t and t.value or 0))
  if total then return string.format('%02d:%02d', math.floor(seconds/3600), math.floor(seconds/60)%60) end
  return string.format('%02d:%02d', math.floor(seconds/60), seconds%60)
end
local function bar(x,y,v)
  local half = 14
  local fill = math.min(half, math.floor(math.abs(v)*half/1024+0.5))
  lcd.drawLine(x,y+1,x+28,y+1,SOLID,0)
  lcd.drawLine(x+half,y,x+half,y+2,SOLID,0)
  if fill > 0 then lcd.drawFilledRectangle(v < 0 and x+half-fill or x+half,y,fill,3) end
end
local function run()
  lcd.clear()
  local fm, mode = getFlightMode()
  local independent = getLogicalSwitchValue(1)
  local rearOnly = value('sc') > 0
  local sa = value('sa')
  local steer = independent and 'INDEP' or rearOnly and '[REAR]' or sa < -512 and '2WS' or sa > 512 and 'CRAB' or '4WS'
  local ratio = math.floor((value('s1')+1024)*100/2048+0.5)
  local coast = getLogicalSwitchValue(4)
  local limit = model.getGlobalVariable(1,fm)
  local expo = model.getGlobalVariable(2,fm)
  local trail = fm == 1
  local coastTime = math.max(1,math.min(50,model.getGlobalVariable(4,0)))/10
  lcd.drawFilledRectangle(0,0,128,9)
  text(1,1,'Bouncer',INVERS)
  text(127,1,trail and 'TRAIL (FL1)' or 'CRAWL '..string.upper(mode or 'SLOW')..' (T3)',INVERS+RIGHT)
  -- Full control state, including settings that are currently overridden.
  text(2,10,steer)
  if not independent then
    text(35,10,steer == 'CRAB' and 'Rear mix off' or ratio..'% RM (P1)')
  end
  text(126,10,'E'..expo,RIGHT)
  text(2,18,'INDEP '..(independent and 'ON' or 'OFF')..' (T4)')
  if independent then text(126,18,'P2 REAR',RIGHT) end
  if trail then
    text(2,26,'COAST '..(coast and 'ON' or 'OFF')..' (FL2)')
    if coast then text(126,26,string.format('%.1fs (T5)',coastTime),RIGHT) end
  end
  lcd.drawLine(0,34,127,34,SOLID,0)
  -- Live channel outputs after output calibration: F front, T throttle, R rear.
  for i, name in ipairs({'ch1','ch2','ch3'}) do
    local x = (i-1)*43
    local v = value(name)
    text(x+1,36,({'F','T','R'})[i])
    text(x+39,36,i == 2 and limit..'%' or string.format('%+d',pct(v)),RIGHT)
    bar(x+6,43,v)
  end
  local battery, lq, rssi = sensor('RxBt'), sensor('RQly'), sensor('1RSS')
  text(1,47,battery and string.format('%.1fV',battery) or '--.-V')
  text(48,47,lq and string.format('LQ%03d',lq) or 'LQ---')
  text(127,47,rssi and string.format('%ddB',rssi) or 'NO RX',RIGHT)
  lcd.drawFilledRectangle(0,56,128,8)
  text(1,57,'D'..timer(0,false),INVERS)
  text(35,57,'T'..timer(2,true),INVERS)
  local now = getDateTime()
  text(70,57,string.format('%02d:%02d',now.hour,now.min),INVERS)
  text(127,57,string.format('TX%.1fV',value('tx-voltage')),INVERS+RIGHT)
  return 0
end
return {init=init,run=run}
