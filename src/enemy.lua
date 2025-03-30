Enemy = setmetatable({}, MovableObject)
Enemy.__index = Enemy

local MOVE_INTERVAL = 60

function Enemy.new(x, y, area)
  local self = MovableObject.new(x, y, area .. "/enemy", 3, 1)
  setmetatable(self, Enemy)
  self.timer = 0
  self.dir = 0
  return self
end

function Enemy:update(level)
  self:animate({1, 2, 3, 2}, 12)

  self.timer = self.timer + 1
  if self.timer == MOVE_INTERVAL then
    level:enemy_move(self)
    self.timer = 0
  end

  level:check_man(self)
end
