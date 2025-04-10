require("src.movable_object")
require("src.ball")
require("src.box")
require("src.door")
require("src.enemy")
require("src.man")
require("src.text_effect")

local EFFECT_DURATION = 150

MenuButton = setmetatable({}, Button)
MenuButton.__index = MenuButton

function MenuButton.new(x, y, text_id, sh_key, sh_key_text, action, center)
  local self = Button.new(x, y, {font = Game.font, text = "", img_path = "button2", anchor = center and "center" or "top_right"}, function(_)
    action()
    Game.play_sound("click")
  end)
  setmetatable(self, MenuButton)
  self.text_id = text_id
  self.sh_key = sh_key
  self.sh_key_text = sh_key_text
  return self
end

function MenuButton:change_text(text_id)
  self.text_id = text_id
  if self.gp_button then
    self.text = Localization.text(text_id)
  else
    self.text = Localization.text(text_id) .. " (" .. self.sh_key_text .. ")"
  end
  self:set_position(self.x, self.y)
end

function MenuButton:toggle_gamepad(connected)
  if connected then
    self.margin_x = -22
    self.text = Localization.text(self.text_id)
    local gp_button_img
    if self.sh_key == "confirm" then gp_button_img = "gpA"
    elseif self.sh_key == "cancel" then gp_button_img = "gpB"
    elseif self.sh_key == "undo" then gp_button_img = "gpX"
    elseif self.sh_key == "restart" then gp_button_img = "gpY"
    elseif self.sh_key == "pause" then gp_button_img = "gpStart"
    elseif self.sh_key == "quit" then gp_button_img = "gpBack"
    end
    self.gp_button = Res.img(gp_button_img)
  else
    self.margin_x = 0
    self.text = Localization.text(self.text_id) .. " (" .. self.sh_key_text .. ")"
    self.gp_button = nil
  end
  self:set_position(self.x, self.y)
end

function MenuButton:update()
  Button.update(self)
  if self.enabled and Game.key_press(self.sh_key) then
    self.action(self.params)
  end
end

function MenuButton:draw()
  Button.draw(self)
  if self.gp_button then
    self.gp_button:draw(math.floor(self.text_x + Game.font:text_width(self.text) / 2) + 10, self.text_y - 17)
  end
end

Level = {}
Level.__index = Level

function Level.new(number)
  local self = setmetatable({}, Level)
  self.number = number

  local area_number = math.floor((number - 1) / 10)
  if area_number == 0 then self.area_name = "room"
  elseif area_number == 1 then self.area_name = "forest"
  elseif area_number == 2 then self.area_name = "desert"
  elseif area_number == 3 then self.area_name = "snow"
  else self.area_name = "cave"
  end

  self.bg = Res.img(self.area_name .. "/back")
  self.tile_floor = Res.img(self.area_name .. "/ground")
  self.tile_wall = Res.img(self.area_name .. "/block")
  self.tile_aim = Res.img(self.area_name .. "/aim")
  self.holes = Res.tileset("holeset", 4, 4)
  self.set_box = Res.img("box2")
  self.lock = Res.img("lock")
  self.key_imgs = {
    r = Res.img("kr"),
    b = Res.img("kb"),
    y = Res.img("ky"),
    g = Res.img("kg")
  }

  local img = love.graphics.newImage("data/img/" .. self.area_name .. "/border.png")
  self.borders = {
    Image.new(img, 0, 0, 20, 20),   -- top left
    Image.new(img, 20, 0, 50, 20),  -- top
    Image.new(img, 70, 0, 20, 20),  -- top right
    Image.new(img, 0, 20, 20, 50),  -- left
    Image.new(img, 70, 20, 20, 50), -- right
    Image.new(img, 0, 70, 20, 20),  -- bottom left
    Image.new(img, 20, 70, 50, 20), -- bottom
    Image.new(img, 70, 70, 20, 20), -- bottom right
  }

  self.text_helper = TextHelper.new(Game.font)
  self.text_helper_big = TextHelper.new(Game.big_font)

  self.pause_button = MenuButton.new(20, 20, "pause", "pause", "_", function(_)
    self.paused = not self.paused
    self.pause_button:change_text(self.paused and "resume" or "pause")
    self.undo_button.enabled = not self.paused
  end)
  self.undo_button = MenuButton.new(20, 100, "undo", "undo", "Z", function(_)
    self:undo()
  end)
  self.buttons = {
    self.pause_button,
    self.undo_button,
    MenuButton.new(20, 180, "restart", "restart", "R", function(_)
      self.confirmation = "restart"
    end),
    MenuButton.new(20, 260, "quit", "quit", "Esc", function(_)
      self.confirmation = "quit"
    end)
  }

  self.panel = Res.img("panel")
  self.confirm_buttons = {
    MenuButton.new(-130, 105, "yes", "confirm", "Q", function(_)
      if self.confirmation == "restart" then
        Game.register_attempt()
        self:start()
      elseif self.confirmation == "quit" then
        Game.quit()
      elseif self.confirmation == "next_level" then
        Game.next_level()
      end
    end, true),
    MenuButton.new(130, 105, "no", "cancel", "W", function(_)
      if self.confirmation == "next_level" then
        self.replay = true
        self.replay_step = 1
        self.replay_timer = 0
        self:start()
      else
        self.confirmation = nil
      end
    end, true)
  }

  self.replay_interval = 15
  self.replay_buttons = {
    MenuButton.new(20, 20, "finish", "quit", "Esc", function(_)
      self.confirmation = "next_level"
    end),
    Button.new(230, 100, {img_path = "less", anchor = "top_right"}, function(_)
      self:reduce_replay_speed()
    end),
    Button.new(20, 100, {img_path = "more", anchor = "top_right"}, function(_)
      self:increase_replay_speed()
    end)
  }

  self:toggle_gamepad(love.joystick.getJoystickCount() > 0)
  self:start()
  Game.play_song(self.area_name)

  return self
end

function Level:start()
  self.confirmation = nil
  self.effect = nil
  self.effect_timer = 0
  if self.paused then
    self.paused = false
    self.pause_button:change_text("pause")
    self.undo_button.enabled = true
  end

  self.aim_count = 0
  self.set_count = 0
  self.key_count = {
    r = 0,
    b = 0,
    y = 0,
    g = 0
  }

  contents = love.filesystem.read("data/levels/lvl" .. self.number)
  local lines = Utils.split(contents, "\n")
  self.start_col = tonumber(lines[1])
  self.start_row = tonumber(lines[2])
  self.width = #lines[3]
  self.height = #lines - 2
  self.margin_x = (SCREEN_WIDTH - TILE_SIZE * self.width) / 2
  self.margin_y = (SCREEN_HEIGHT - TILE_SIZE * self.height) / 2
  table.remove(lines, 1)
  table.remove(lines, 1)

  self.tiles = {}
  for i = 1, self.width do
    self.tiles[i] = {}
    for j = 1, self.height do self.tiles[i][j] = nil end
  end
  self.objects = {}
  for i = 1, self.width do
    self.objects[i] = {}
    for j = 1, self.height do self.objects[i][j] = {} end
  end
  self.enemies = {}

  for j, line in ipairs(lines) do
    local i = 1
    for c in line:gmatch(".") do
      if c == "o" or c == "+" then
        table.insert(self.objects[i][j], Ball.new(self.margin_x + (i - 1) * TILE_SIZE, self.margin_y + (j - 1) * TILE_SIZE, self.area_name, c == "+"))
      elseif c == "R" or c == "B" or c == "Y" or c == "G" then
        table.insert(self.objects[i][j], Door.new(self.margin_x + (i - 1) * TILE_SIZE, self.margin_y + (j - 1) * TILE_SIZE, c:lower()))
      elseif c == "c" then
        table.insert(self.objects[i][j], Box.new(self.margin_x + (i - 1) * TILE_SIZE, self.margin_y + (j - 1) * TILE_SIZE))
      elseif c == "e" then
        local enemy = Enemy.new(self.margin_x + (i - 1) * TILE_SIZE, self.margin_y + (j - 1) * TILE_SIZE, self.area_name)
        table.insert(self.objects[i][j], enemy)
        table.insert(self.enemies, enemy)
      end
      if c == "+" then
        self.set_count = self.set_count + 1
        c = "x"
      end
      if c == "x" then
        self.aim_count = self.aim_count + 1
      end
      self.tiles[i][j] = c
      i = i + 1
    end
  end

  self.man = Man.new(self.margin_x + self.start_col * TILE_SIZE, self.margin_y + self.start_row * TILE_SIZE)
  if not self.replay then self.history = {} end
end

function Level:toggle_gamepad(connected)
  for _, b in ipairs(self.buttons) do b:toggle_gamepad(connected) end
  for _, b in ipairs(self.confirm_buttons) do b:toggle_gamepad(connected) end
  self.replay_buttons[1]:toggle_gamepad(connected)
end

function Level:move_object(obj, i1, j1, i2, j2)
  for index, o in ipairs(self.objects[i1][j1]) do
    if o == obj then
      table.remove(self.objects[i1][j1], index)
      break
    end
  end
  table.insert(self.objects[i2][j2], obj)
end

function Level:player_move(i, j, i_var, j_var)
  local n_i = i + i_var
  local n_j = j + j_var
  if n_i < 1 or n_i > self.width or n_j < 1 or n_j > self.height or
     self.tiles[n_i][n_j] == "#" or self.tiles[n_i][n_j] == "h" then
    return
  end

  local step = {}
  local objs = self.objects[n_i][n_j]
  local nn_i = n_i + i_var
  local nn_j = n_j + j_var
  local blocked = false
  for index, obj in ipairs(objs) do
    if getmetatable(obj) == Ball then
      if self:obstacle_at(nn_i, nn_j) or self.tiles[n_i][n_j] == "l" or self.tiles[nn_i][nn_j] == "h" then
        blocked = true
        break
      end

      local will_set = self.tiles[nn_i][nn_j] == "x"
      if will_set and not obj.set then
        self.set_count = self.set_count + 1
        step.set_change = 1
      elseif not will_set and obj.set then
        self.set_count = self.set_count - 1
        step.set_change = -1
      end

      self:move_object(obj, n_i, n_j, nn_i, nn_j)
      obj:move(i_var * TILE_SIZE, j_var * TILE_SIZE)
      obj.set = will_set
      step.obj_move = {
        obj = obj,
        from = {n_i, n_j},
        to = {nn_i, nn_j},
        ball = true
      }
      Game.play_sound("push")
    elseif getmetatable(obj) == Door then
      if self.key_count[obj.color] > 0 then
        table.remove(self.objects[n_i][n_j], index)
        self.key_count[obj.color] = self.key_count[obj.color] - 1
        step.obj_remove = {
          obj = obj,
          from = {n_i, n_j}
        }
        step.key_use = obj.color
        Game.play_sound("open")
      else
        blocked = true
        break
      end
    elseif getmetatable(obj) == Box then
      if self:obstacle_at(nn_i, nn_j, false) or self.tiles[n_i][n_j] == "l" then
        blocked = true
        break
      end

      table.remove(self.objects[n_i][n_j], index)
      if self.tiles[nn_i][nn_j] == "h" then
        self.tiles[nn_i][nn_j] = "H"
        step.obj_remove = {
          obj = obj,
          from = {n_i, n_j}
        }
        step.hole_cover = {nn_i, nn_j}
      else
        table.insert(self.objects[nn_i][nn_j], obj)
        obj:move(i_var * TILE_SIZE, j_var * TILE_SIZE)
        step.obj_move = {
          obj = obj,
          from = {n_i, n_j},
          to = {nn_i, nn_j}
        }
      end
      Game.play_sound("push")
    end
  end
  if blocked then return end

  if self.tiles[n_i][n_j]:find("[rbyg]") then
    color = self.tiles[n_i][n_j]
    self.key_count[color] = self.key_count[color] + 1
    self.tiles[n_i][n_j] = "."
    step.key_add = {
      color = color,
      from = {n_i, n_j}
    }
  end

  self.man:move(i_var * TILE_SIZE, j_var * TILE_SIZE)
  step.player = {i, j, i_var, j_var, self.man.dir}
  step.enemies = {}
  for _, e in ipairs(self.enemies) do
    table.insert(step.enemies, {e.x, e.y, e.dir, e.timer})
  end
  if not self.replay then
    table.insert(self.history, step)
  end
end

function Level:enemy_move(enemy)
  local tries = 0
  local i = math.floor((enemy.x - self.margin_x) / TILE_SIZE) + 1
  local j = math.floor((enemy.y - self.margin_y) / TILE_SIZE) + 1
  while tries < 4 do
    local i_var, j_var
    if enemy.dir == 0 then i_var, j_var = 0, -1
    elseif enemy.dir == 1 then i_var, j_var = 1, 0
    elseif enemy.dir == 2 then i_var, j_var = 0, 1
    else i_var, j_var = -1, 0
    end
    if self:obstacle_at(i + i_var, j + j_var) then
      tries = tries + 1
      enemy.dir = (enemy.dir + tries) % 4
    else
      self:move_object(enemy, i, j, i + i_var, j + j_var)
      enemy:move(i_var * TILE_SIZE, j_var * TILE_SIZE)
      break
    end
  end
end

function Level:check_man(enemy)
  local i = math.floor((enemy.x - self.margin_x) / TILE_SIZE) + 1
  local j = math.floor((enemy.y - self.margin_y) / TILE_SIZE) + 1
  local m_i = math.floor((self.man.x - self.margin_x) / TILE_SIZE) + 1
  local m_j = math.floor((self.man.y - self.margin_y) / TILE_SIZE) + 1
  if i == m_i and j == m_j then
    self.effect = TextEffect.new("try_again", {1, 0.4, 0.4})
  end
end

function Level:obstacle_at(i, j, check_hole)
  check_hole = check_hole or check_hole == nil
  if i < 1 or i > self.width or j < 1 or j > self.height or
     self.tiles[i][j] == "#" or
     check_hole and self.tiles[i][j] == "h" then
    return true
  end

  for _, obj in ipairs(self.objects[i][j]) do
    local metatable = getmetatable(obj)
    if metatable == Ball or metatable == Box or metatable == Door then
      return true
    end
  end
  return false
end

function Level:reposition_enemies(step)
  for ind, e in ipairs(self.enemies) do
    local i = math.floor((e.x - self.margin_x) / TILE_SIZE) + 1
    local j = math.floor((e.y - self.margin_y) / TILE_SIZE) + 1
    e.x = step.enemies[ind][1]
    e.y = step.enemies[ind][2]
    local n_i = math.floor((e.x - self.margin_x) / TILE_SIZE) + 1
    local n_j = math.floor((e.y - self.margin_y) / TILE_SIZE) + 1
    self:move_object(e, i, j, n_i, n_j)

    e.dir = step.enemies[ind][3]
    e.timer = step.enemies[ind][4]
  end
end

function Level:undo()
  if #self.history == 0 then return end

  local step = table.remove(self.history)

  if step.set_change then
    self.set_count = self.set_count - step.set_change
  end

  if step.obj_move then
    local obj = step.obj_move.obj
    local from = {step.obj_move.from[1], step.obj_move.from[2]}
    local to = {step.obj_move.to[1], step.obj_move.to[2]}
    self:move_object(obj, to[1], to[2], from[1], from[2])
    obj:move((from[1] - to[1]) * TILE_SIZE, (from[2] - to[2]) * TILE_SIZE)
    if step.obj_move.ball then
      obj.set = self.tiles[from[1]][from[2]] == "x"
    end
  end

  if step.obj_remove then
    table.insert(self.objects[step.obj_remove.from[1]][step.obj_remove.from[2]], step.obj_remove.obj)
  end

  if step.key_use then
    self.key_count[step.key_use] = self.key_count[step.key_use] + 1
  end

  if step.hole_cover then
    self.tiles[step.hole_cover[1]][step.hole_cover[2]] = "h"
  end

  if step.key_add then
    self.key_count[step.key_add.color] = self.key_count[step.key_add.color] - 1
    self.tiles[step.key_add.from[1]][step.key_add.from[2]] = step.key_add.color
  end

  self:reposition_enemies(step)

  self.man.x = self.margin_x + (step.player[1] - 1) * TILE_SIZE
  self.man.y = self.margin_y + (step.player[2] - 1) * TILE_SIZE
  self.man:set_dir(step.player[5])
end

function Level:redo()
  local step = self.history[self.replay_step]
  local i_var = step.player[3]
  local j_var = step.player[4]
  self:player_move(step.player[1], step.player[2], i_var, j_var)
  if j_var < 0 then
    self.man:set_dir(0)
  elseif i_var > 0 then
    self.man:set_dir(1)
  elseif j_var > 0 then
    self.man:set_dir(2)
  else
    self.man:set_dir(3)
  end
  self:reposition_enemies(step)
end

function Level:reduce_replay_speed()
  if self.replay_interval < 15 then
    self.replay_interval = 15
  elseif self.replay_interval < 30 then
    self.replay_interval = 30
  end
end

function Level:increase_replay_speed()
  if self.replay_interval > 15 then
    self.replay_interval = 15
  elseif self.replay_interval > 7 then
    self.replay_interval = 7
  end
end

function Level:congratulate()
  self.effect = TextEffect.new("congratulations", {0.75, 0.75, 1})
  self.effect_timer = -150
end

function Level:update()
  if self.confirmation then
    for _, b in ipairs(self.confirm_buttons) do b:update() end
  elseif self.effect then
    self.effect:update()
    self.effect_timer = self.effect_timer + 1
    if self.effect_timer == EFFECT_DURATION then
      if self.effect.type == "won" then
        if self.number < LEVEL_COUNT or self.replay then
          self.confirmation = "next_level"
          self.confirm_buttons[1]:change_text("next_level")
          self.confirm_buttons[2]:change_text("view_replay")
        else
          self:congratulate()
        end
      elseif self.effect.type ==  "try_again" then
        Game.register_attempt()
        self:start()
      elseif self.effect.type == "congratulations" then
        self.confirmation = "next_level"
        self.confirm_buttons[1]:change_text("next_level")
        self.confirm_buttons[2]:change_text("view_replay")
      end
    end
  elseif self.replay then
    for _, b in ipairs(self.replay_buttons) do b:update() end
  else
    for _, b in ipairs(self.buttons) do b:update() end
  end
  if self.confirmation or self.effect or self.paused then return end

  local prev_count = self.set_count

  if self.replay then
    self.replay_timer = self.replay_timer + 1
    if self.replay_timer >= self.replay_interval then
      self:redo()
      self.replay_step = self.replay_step + 1
      self.replay_timer = 0
    end

    if Game.key_press("left") then
      self:reduce_replay_speed()
    elseif Game.key_press("right") then
      self:increase_replay_speed()
    end
  else
    local i = math.floor((self.man.x - self.margin_x) / TILE_SIZE) + 1
    local j = math.floor((self.man.y - self.margin_y) / TILE_SIZE) + 1
    if Game.key_press("up", true) then
      self:player_move(i, j, 0, -1)
      self.man:set_dir(0)
    elseif Game.key_press("right", true) then
      self:player_move(i, j, 1, 0)
      self.man:set_dir(1)
    elseif Game.key_press("down", true) then
      self:player_move(i, j, 0, 1)
      self.man:set_dir(2)
    elseif Game.key_press("left", true) then
      self:player_move(i, j, -1, 0)
      self.man:set_dir(3)
    end
  end

  local objects_to_update = {}
  for _, col in ipairs(self.objects) do
    for _, cell in ipairs(col) do
      for _, obj in ipairs(cell) do
        if obj.update then table.insert(objects_to_update, obj) end
      end
    end
  end
  for _, obj in ipairs(objects_to_update) do
    obj:update(self)
  end
  self.man:update()

  if not self.effect and prev_count < self.aim_count and self.set_count == self.aim_count then
    self.effect = TextEffect.new("won", {1, 1, 1})
    Game.play_sound("clear")
  end
end

function Level:get_hole(i, j)
  local up = j > 1 and (self.tiles[i][j - 1] == "h" or self.tiles[i][j - 1] == "H")
  local rt = i < self.width and (self.tiles[i + 1][j] == "h" or self.tiles[i + 1][j] == "H")
  local dn = j < self.height and (self.tiles[i][j + 1] == "h" or self.tiles[i][j + 1] == "H")
  local lf = i > 1 and (self.tiles[i - 1][j] == "h" or self.tiles[i - 1][j] == "H")
  if up and rt and dn and lf then return 11 end
  if up and rt and dn then return 3 end
  if up and rt and lf then return 7 end
  if up and dn and lf then return 8 end
  if rt and dn and lf then return 4 end
  if up and rt then return 5 end
  if up and dn then return 15 end
  if up and lf then return 6 end
  if rt and dn then return 1 end
  if rt and lf then return 12 end
  if dn and lf then return 2 end
  if up then return 14 end
  if rt then return 13 end
  if dn then return 9 end
  if lf then return 10 end
  return 16
end

function Level:draw()
  for i = 0, BG_TILES_X do
    for j = 0, BG_TILES_Y do
      self.bg:draw(i * self.bg.width, j * self.bg.height)
    end
  end

  self.borders[1]:draw(self.margin_x - 20, self.margin_y - 20)
  self.borders[3]:draw(SCREEN_WIDTH - self.margin_x, self.margin_y - 20)
  self.borders[6]:draw(self.margin_x - 20, SCREEN_HEIGHT - self.margin_y)
  self.borders[8]:draw(SCREEN_WIDTH - self.margin_x, SCREEN_HEIGHT - self.margin_y)
  for i = 1, self.width do
    local x = self.margin_x + (i - 1) * TILE_SIZE
    self.borders[2]:draw(x, self.margin_y - 20)
    self.borders[7]:draw(x, SCREEN_HEIGHT - self.margin_y)
    for j = 1, self.height do
      local y = self.margin_y + (j - 1) * TILE_SIZE

      if i == 1 then
        self.borders[4]:draw(self.margin_x - 20, y)
        self.borders[5]:draw(SCREEN_WIDTH - self.margin_x, y)
      end

      self.tile_floor:draw(x, y)
      local tile = self.tiles[i][j]
      local overlay
      if tile == '#' then overlay = self.tile_wall
      elseif tile == 'x' then overlay = self.tile_aim
      elseif tile and tile:find("[rbyg]") then overlay = self.key_imgs[tile]
      elseif tile == "h" or tile == "H" then overlay = self.holes[self:get_hole(i, j)]
      elseif tile == "l" then overlay = self.lock
      end
      if overlay then overlay:draw(x, y) end

      if i > 1 and j > 1 then
        local tl = self.tiles[i - 1][j - 1] == "h" or self.tiles[i - 1][j - 1] == "H"
        local tr = self.tiles[i][j - 1] == "h" or self.tiles[i][j - 1] == "H"
        local bl = self.tiles[i - 1][j] == "h" or self.tiles[i - 1][j] == "H"
        local br = tile == "h" or tile == "H"
        if tl and tr and bl and br then
          Window.draw_rectangle(x - 0.5 * TILE_SIZE, y - 0.5 * TILE_SIZE, TILE_SIZE, TILE_SIZE, {0.266667, 0.266667, 0.266667})
        end
      end

      if tile == "H" then self.set_box:draw(x, y) end
    end
  end

  for _, col in ipairs(self.objects) do
    for _, cell in ipairs(col) do
      for _, obj in ipairs(cell) do obj:draw() end
    end
  end
  self.man:draw()

  self.text_helper_big:write_line(Localization.text("level") .. " " .. self.number, 20, 20, "left", {1, 1, 1}, "shadow")
  self.key_imgs.r:draw(20, 70, 0.6, 0.6)
  self.text_helper:write_line(self.key_count.r, 60, 71, "left", {1, 0, 0}, "shadow")
  self.key_imgs.b:draw(20, 110, 0.6, 0.6)
  self.text_helper:write_line(self.key_count.b, 60, 111, "left", {0, 0, 1}, "shadow")
  self.key_imgs.y:draw(20, 150, 0.6, 0.6)
  self.text_helper:write_line(self.key_count.y, 60, 151, "left", {0.75, 0.75, 0}, "shadow")
  self.key_imgs.g:draw(20, 190, 0.6, 0.6)
  self.text_helper:write_line(self.key_count.g, 60, 191, "left", {0, 0.5, 0}, "shadow")

  if self.replay then
    for _, b in ipairs(self.replay_buttons) do b:draw() end
    local text = self.replay_interval == 7 and "fast" or (self.replay_interval == 15 and "normal" or "slow")
    self.text_helper:write_line(Localization.text(text), SCREEN_WIDTH - 145, 115, "center", {0, 0, 0})
  else
    for _, b in ipairs(self.buttons) do b:draw() end
  end

  if self.confirmation then
    Window.draw_rectangle(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, {0, 0, 0, 0.5})
    local panel_x = (SCREEN_WIDTH - self.panel.width) / 2
    local panel_y = (SCREEN_HEIGHT - self.panel.height) / 2
    self.panel:draw(panel_x, panel_y)
    if self.confirmation == "next_level" then
      self.text_helper_big:write_line(Localization.text("won"), SCREEN_WIDTH / 2, panel_y + 70, "center", {0, 0, 0})
    else
      self.text_helper_big:write_line(Localization.text(self.confirmation), SCREEN_WIDTH / 2, panel_y + 70, "center", {0, 0, 0})
      self.text_helper:write_line(Localization.text("are_you_sure"), SCREEN_WIDTH / 2, panel_y + 120, "center", {0, 0, 0})
    end
    for _, b in ipairs(self.confirm_buttons) do b:draw() end
  elseif self.effect then
    self.effect:draw()
  end
end
