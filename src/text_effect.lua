TextEffect = {}
TextEffect.__index = TextEffect

function TextEffect.new(type, color)
  local self = setmetatable({}, TextEffect)
  self.type = type
  self.text = Localization.text(type)
  self.color = color
  self.x = -300
  self.y = (SCREEN_HEIGHT - Game.big_font.height) / 2
  self.text_helper = TextHelper.new(Game.big_font)
  return self
end

function TextEffect:update()
  local d_x = SCREEN_WIDTH / 2 - self.x
  if d_x == 0 then return end

  if d_x <= 1 then
    self.x = SCREEN_WIDTH / 2
    return
  end

  self.x = self.x + d_x * 0.1
end

function TextEffect:draw()
  self.text_helper:write_line(self.text, self.x, self.y, "center", self.color, "shadow", 2)
end
