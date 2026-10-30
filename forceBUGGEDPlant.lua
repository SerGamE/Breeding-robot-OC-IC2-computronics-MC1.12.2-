local r = require("robot")

-- Хранение позиции и направления: 0-север(вперед), 1-восток(вправо), 2-юг(назад), 3-запад(влево)
local curX, curY, curDir = 0, 0, 0

-- Новые базовые функции поворотов и движения с отслеживанием координат
local function turnRight() r.turnRight() curDir = (curDir + 1) % 4 end
local function turnLeft()  r.turnLeft()  curDir = (curDir - 1) % 4 end

local function forward()
  if r.forward() then
    if curDir == 0 then curY = curY + 1
    elseif curDir == 1 then curX = curX + 1
    elseif curDir == 2 then curY = curY - 1
    elseif curDir == 3 then curX = curX - 1
    end
    return true
  end
  return false
end

local function backward()
  if r.backward() then
    if curDir == 0 then curY = curY - 1
    elseif curDir == 1 then curX = curX - 1
    elseif curDir == 2 then curY = curY + 1
    elseif curDir == 3 then curX = curX + 1
    end
    return true
  end
  return false
end
--внешние, глобальные функции
function righter() turnRight() forward() turnRight() forward() r.placeDown() end 
function lefter() turnLeft() forward() turnLeft() forward() r.placeDown() end 
function twoStep() forward() forward() r.placeDown() end 
function runCount(count) for i=1, count do forward() end end 
function moonWalk(count) for i=1, count do backward() end end

-- Внутренние функции перемещения и возврата домой
local function goTo(targetX, targetY)
  if curX ~= targetX then
    local targetDir = targetX > curX and 1 or 3
    while curDir ~= targetDir do turnRight() end
    while curX ~= targetX do forward() end
  end
  if curY ~= targetY then
    local targetDir = targetY > curY and 0 or 2
    while curDir ~= targetDir do turnRight() end
    while curY ~= targetY do forward() end
  end
end

local function returnHome()
  goTo(0, 0)
  while curDir ~= 0 do turnRight() end
end

-- Итоговая функция FieldPlace
function FieldPlace(x, y, start, invert)
  curX, curY, curDir = 0, 0, 0 
  if invert == nil then invert = false end
  
  -- Идем на стартовую позицию площадки
  goTo(start.x, start.y)
  while curDir ~= 0 do turnRight() end

  -- Настройка логики шахматного порядка
  local totalSteps = invert and 1 or 0
  if totalSteps % 2 == 0 then r.placeDown() end

  local function moveAndPlace()
    if forward() then
      totalSteps = totalSteps + 1
      if totalSteps % 2 == 0 then 
        r.select(1)
        r.placeDown()
        r.select(3)
        r.placeDown()
      end
    end
  end

  -- Движение змейкой
  for row = 1, y do
    for col = 1, x - 1 do moveAndPlace() end
    if row < y then
      if row % 2 == 1 then
        turnRight() moveAndPlace() turnRight()
      else
        turnLeft() moveAndPlace() turnLeft()
      end
    end
  end
  
  returnHome()
end
