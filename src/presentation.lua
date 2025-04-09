Presentation = {}
Presentation.__index = Presentation

function Presentation.new()
  local self = setmetatable({}, Presentation)
  self.logo = Res.img("minigl")
  self.huge_font = Res.font("font", 64)
  self.timer = 0
  Game.play_song("theme")
  return self
end

function Presentation:update()
  self.timer = self.timer + 1
  if Game.key_press("confirm") or Game.key_press("quit") or Mouse.pressed("left") or self.timer >= 420 then
    Game.open_menu()
  end
end

function Presentation:draw()
  local alpha
  if self.timer <= 195 then
    if self.timer <= 30 then
      alpha = self.timer / 30
    elseif self.timer <= 165 then
      alpha = 1
    else
      alpha = (195 - self.timer) / 30
    end
    local color = {1, 1, 1, alpha}
    self.logo:draw((SCREEN_WIDTH - self.logo.width) / 2, (SCREEN_HEIGHT - self.logo.height) / 2, 1, 1, nil, color)
    Game.big_font:draw_text_rel(Localization.text("powered_by"), SCREEN_WIDTH / 2, (SCREEN_HEIGHT - self.logo.height) / 2 - 80, 0.5, 0, color)
  else
    if self.timer <= 225 then
      alpha = (self.timer - 195) / 30
    else
      alpha = 1
    end
    local color = {1, 1, 1, alpha}
    Game.big_font:draw_text_rel(Localization.text("game_by"), SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - 60, 0.5, 0, color)
    self.huge_font:draw_text_rel('Victor David Santos', SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 - 20, 0.5, 0, color)
  end
end
