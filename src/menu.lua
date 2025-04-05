MainButton = setmetatable({}, Button)
MainButton.__index = MainButton

function MainButton.new(y, text_id, icon, action)
  local self = Button.new(285, y, {font = Game.big_font, text = Localization.text(text_id), img_path = "button", center_x = false, margin_x = 70, margin_y = -4}, function(_)
    action()
    Game.play_sound("click")
  end)
  setmetatable(self, MainButton)
  self.text_id = text_id
  self.icon = Res.img(icon)
  self.highlight = Res.img("btnHighlight")
  return self
end

function MainButton:update_text()
  self.text = Localization.text(self.text_id)
end

function MainButton:draw(color)
  Button.draw(self, color)
  self.icon:draw(self.x, self.y)
end

function MainButton:draw_highlight()
  self.highlight:draw(self.x, self.y)
end

LevelButton = setmetatable({}, Button)
LevelButton.__index = LevelButton

function LevelButton.new(x, y, number)
  local self = Button.new(x, y, {font = Game.big_font, text = tostring(number), img_path = "button3", margin_x = -5, margin_y = -4}, function(_)
    Game.play_sound("click")
    Game.start(number)
  end)
  setmetatable(self, LevelButton)
  self.highlight = Res.img("btn3Highlight")
  return self
end

function LevelButton:draw_highlight()
  self.highlight:draw(self.x, self.y)
end

OptionButton = setmetatable({}, Button)
OptionButton.__index = OptionButton

function OptionButton.new(x, y, img, action)
  local self = Button.new(x, y, {img_path = img}, function(_)
    action()
    Game.play_sound("click")
  end)
  setmetatable(self, OptionButton)
  self.highlight = Res.img(img .. "Highlight")
  return self
end

function OptionButton:draw_highlight()
  self.highlight:draw(self.x - 4, self.y - 4)
end

Menu = {}
Menu.__index = Menu

function Menu.new()
  local self = setmetatable({}, Menu)
  self.bg = Res.img("menu")
  self.panel = Res.img("panel")
  self.text_helper = TextHelper.new(Game.font)

  local back_btn = MainButton.new(540, "back", "back", function(_)
    Menu.set_state(self, "main")
  end)

  local level_btns = {}
  for i = 0, Game.last_level - 1 do
    table.insert(level_btns, LevelButton.new(55 + (i % 10) * 70, 240 + math.floor(i / 10) * 60, i + 1))
  end
  table.insert(level_btns, back_btn)

  self.btns = {
    main = {
      MainButton.new(260, "play", "play", function(_)
        Menu.set_state(self, "play")
      end),
      MainButton.new(320, "instructions", "help", function(_)
        Menu.set_state(self, "instructions")
      end),
      MainButton.new(380, "high_scores", "trophy", function(_)
        Menu.set_state(self, "high_scores")
      end),
      MainButton.new(440, "options", "options", function(_)
        Menu.set_state(self, "options")
      end),
      MainButton.new(500, "exit", "exit", function(_)
        love.event.quit()
      end)
    },
    play = level_btns,
    instructions = {back_btn},
    high_scores = {back_btn},
    options = {
      OptionButton.new(500, 280, "change", function(_)
        Game.toggle_full_screen()
      end),
      OptionButton.new(500, 320, "change", function(_)
        Game.next_language()
        Menu.update_button_texts(self)
      end),
      OptionButton.new(500, 367, "less", function(_)
        Game.change_music_volume(-1)
      end),
      OptionButton.new(522, 367, "more", function(_)
        Game.change_music_volume(1)
      end),
      OptionButton.new(500, 407, "less", function(_)
        Game.change_sound_volume(-1)
      end),
      OptionButton.new(522, 407, "more", function(_)
        Game.change_sound_volume(1)
      end),
      MainButton.new(540, "back", "back", function(_)
        Game.save_config()
        Menu.set_state(self, "main")
      end)
    }
  }

  self.btn_index = 1
  self.state = "main"

  Game.play_song("theme")

  return self
end

function Menu:set_state(state)
  self.state = state
  self.btn_index = 1
end

function Menu:update_button_texts()
  for _, list in ipairs(self.btns) do
    for _, b in ipairs(list) do
      if b.update_text then b:update_text() end
    end
  end
end

function Menu:update()
  if Game.key_press("confirm") or KB.pressed("return") then
    self.btns[self.state][self.btn_index]:click()
  elseif self.state ~= "main" and (Game.key_press("cancel") or Game.key_press("quit")) then
    self:set_state("main")
  elseif Game.key_press("up", true) then
    self.btn_index = self.btn_index - 1
    if self.btn_index < 1 then self.btn_index = #self.btns[self.state] end
  elseif Game.key_press("down", true) then
    self.btn_index = self.btn_index + 1
    if self.btn_index > #self.btns[self.state] then self.btn_index = 1 end
  end

  for _, b in ipairs(self.btns[self.state]) do
    b:update()
  end
end

function Menu:draw()
  self.bg:draw(0, 0)
  if self.state ~= "main" and self.state ~= "play" then
    self.panel:draw(220, 245)
  end

  if self.state == "instructions" then
    self.text_helper:write_breaking(Localization.text("help_text"), 255, 285, 290, "left", {0, 0, 0})
  elseif self.state == "high_scores" then
    Game.font:draw_text(Localization.text("from_level"), 260, 230, {0, 0, 0})
    Game.font:draw_text(Localization.text("to_level"), 360, 230, {0, 0, 0})
    Game.font:draw_text(Localization.text("in_tries"), 460, 230, {0, 0, 0})
    for i = 1, 5 do
      for j = 1, 3 do
        local text = Game.scores[i] and tostring(Game.scores[i][j]) or "-"
        if j == 2 and Game.scores[i] and Game.scores[i][j] == LEVEL_COUNT + 1 then
          text = Localization.text("end")
        end
        Game.font:draw_text(text, 260 + (j - 1) * 100, 275 + (i - 1) * 40, {0, 0, 0})
      end
    end
  elseif self.state == "options" then
    Game.font:draw_text(Localization.text(Game.full_screen and "full_screen" or "window"), 255, 290, {0, 0, 0})
    Game.font:draw_text(Localization.text("lang_name"), 255, 330, {0, 0, 0})
    Game.font:draw_text(Localization.text("music_volume") .. ": " .. Game.music_volume, 255, 370, {0, 0, 0})
    Game.font:draw_text(Localization.text("sound_volume") .. ": " .. Game.sound_volume, 255, 410, {0, 0, 0})
  end

  for i, b in ipairs(self.btns[self.state]) do
    b:draw()
    if i == self.btn_index then
      b:draw_highlight()
    end
  end
end
