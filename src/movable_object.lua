MovableObject = setmetatable({}, Sprite)
MovableObject.__index = MovableObject

function MovableObject:move(x_var, y_var)
  self.x = self.x + x_var
  self.y = self.y + y_var
end
