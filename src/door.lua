Door = setmetatable({}, Sprite)
Door.__index = Door

function Door.new(x, y, color)
  local self = Sprite.new(x, y, "d" .. color)
  setmetatable(self, Door)
  self.color = color
  return self
end
