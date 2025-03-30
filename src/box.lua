Box = setmetatable({}, MovableObject)
Box.__index = Box

function Box.new(x, y)
  local self = MovableObject.new(x, y, "box")
  setmetatable(self, Box)
  return self
end
