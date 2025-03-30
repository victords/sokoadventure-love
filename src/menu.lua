Menu = {}
Menu.__index = Menu

function Menu.new()
  local self = setmetatable({}, Menu)
  return self
end

function Menu:update()
end

function Menu:draw()
end
