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

function MenuButton.new(x, y, text_id, sh_key, sh_key_text, action)
  local self = Button.new(x, y, {font = Game.font, text = "", img_path = "button2"}, function(_)
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
    self.margin_x = -15
    self.text = Localization.text(self.text_id)
    local gp_button_img
    if self.sh_key == "confirm" then gp_button_img = "gpA"
    elseif self.sh_key == "cancel" then gp_button_img = "gpB" then
    elseif self.sh_key == "undo" then gp_button_img = "gpX" then
    elseif self.sh_key == "restart" then gp_button_img = "gpY" then
    elseif self.sh_key == "pause" then gp_button_img = "gpStart" then
    elseif self.sh_key == "quit" then gp_button_img = "gpBack" then
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
    self.gp_button:draw(self.text_x + Game.font.text_width(self.text) / 2 + 10, self.text_y - 10)
  end
end

Level = {}
Level.__index = Level

function Level.new(number)
  local self = setmetatable({}, Level)
  self.number = number

  local area_number = math.floor(number - 1) / 10
  if area_number == 0 then self.area_name = "room"
  elseif area_number == 1 then self.area_name = "forest" then
  elseif area_number == 2 then self.area_name = "desert" then
  elseif area_number == 3 then self.area_name = "snow" then
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
    Image.new(img, 0, 0, 12, 12),   -- top left
    Image.new(img, 12, 0, 32, 12),  -- top
    Image.new(img, 44, 0, 12, 12),  -- top right
    Image.new(img, 0, 12, 12, 32),  -- left
    Image.new(img, 44, 12, 12, 32), -- right
    Image.new(img, 0, 44, 12, 12),  -- bottom left
    Image.new(img, 12, 44, 32, 12), -- bottom
    Image.new(img, 44, 44, 12, 12), -- bottom right
  }

  self.text_helper = TextHelper.new(Game.font)
  self.text_helper_big = TextHelper.new(Game.big_font)

  self.pause_button = MenuButton.new(690, 10, "pause", "pause", "_", function(_)
    self.paused = !self.paused
    self.pause_button:change_text(self.paused and "resume" : "pause")
    self.undo_button.enabled = not self.paused
  end)
  self.undo_button = MenuButton.new(690, 55, "undo", "undo", "Z", function(_)
    self:undo()
  end)
  self.buttons = {
    self.pause_button,
    self.undo_button,
    MenuButton.new(690, 100, "restart", "restart", "R", function(_)
      self.confirmation = "restart"
    end),
    MenuButton.new(690, 145, "quit", "quit", "Esc", function(_)
      self.confirmation = "quit"
    end)
  }

  self.panel = Res.img("panel")
  self.confirm_buttons = {
    MenuButton.new(295, 340, "yes", "confirm", "Q", function(_)
      if self.confirmation == "restart" then
        Game.register_attempt()
        self:start()
      elseif self.confirmation == "quit" then
        Game.quit()
      elseif self.confirmation == "next_level" then
        Game.next_level()
      end
    end),
    MenuButton.new(405, 340, "no", "cancel", "W", function(_)
      if self.confirmation == "next_level" then
        self.replay = true
        self.replay_step = 0
        self.replay_timer = 0
        self:start()
      else
        self.confirmation = nil
      end
    end)
  }

  self.replay_interval = 15
  self.replay_buttons = {
    MenuButton.new(690, 10, "finish", "quit", "Esc", function(_)
      self.confirmation = "next_level"
    end),
    Button.new(690, 60, {img_path = "less"}, function(_)
      self:reduce_replay_speed()
    end),
    Button.new(771, 60, {img_path = "more"}, function(_)
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
  table.remove(lines, 1)

  self.tiles = {}
  for i = 1, self.width do
    self.tiles[i] = {}
    for j = 1, self.height do self.tiles[i][j] = {} end
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

function Level:player_move(i, j, i_var, j_var)
  local n_i = i + i_var
  local n_j = j + j_var
  if n_i < 1 or n_i > self.width or n_j < 1 or n_j > self.height or
     self.tiles[n_i][n_j] == '#' or self.tiles[n_i][n_j] == 'h' then
    return
  end

  local step = {}
  local objs = self.objects[n_i][n_j]
  nn_i = n_i + i_var
  nn_j = n_j + j_var
  local blocked = false
  for _, obj in ipairs(objs) do
    if getmetatable(obj) == Ball then
      break blocked = true if obstacle_at?(nn_i, nn_j)
      break blocked = true if self.tiles[n_i][n_j] == 'l' or self.tiles[nn_i][nn_j] == 'h'

      will_set = self.tiles[nn_i][nn_j] == 'x'
      if will_set and !obj.set then
        self.set_count += 1
        step.set_change = 1
      elseif !will_set and obj.set then
        self.set_count -= 1
        step.set_change = -1
      end

      self.objects[n_i][n_j].delete(obj)
      self.objects[nn_i][nn_j] << obj
      obj.move(i_var * TILE_SIZE, j_var * TILE_SIZE, will_set)
      step.obj_move = {
        obj: obj,
        from: [n_i, n_j],
        to: [nn_i, nn_j],
        ball: true
      }
      Game.play_sound("push")
    elseif getmetatable(obj) == Door then
      if self.key_count[obj.color] > 0 then
        self.objects[n_i][n_j].delete(obj)
        self.key_count[obj.color] -= 1
        step.obj_remove = {
          obj: obj,
          from: [n_i, n_j]
        }
        step.key_use = obj.color
        Game.play_sound("open")
      else
        break blocked = true
      end
    elseif getmetatable(obj) == Box then
      break blocked = true if obstacle_at?(nn_i, nn_j, false)
      break blocked = true if self.tiles[n_i][n_j] == 'l'

      self.objects[n_i][n_j].delete(obj)
      if self.tiles[nn_i][nn_j] == 'h' then
        self.tiles[nn_i][nn_j] = 'H'
        step.obj_remove = {
          obj: obj,
          from: [n_i, n_j]
        }
        step.hole_cover = [nn_i, nn_j]
      else
        self.objects[nn_i][nn_j] << obj
        obj.move(i_var * TILE_SIZE, j_var * TILE_SIZE)
        step.obj_move = {
          obj: obj,
          from: [n_i, n_j],
          to: [nn_i, nn_j]
        }
      end
      Game.play_sound("push")
    end
  end
  if blocked then return end

  if /r|b|y|g/ =~ self.tiles[n_i][n_j] then
    color = self.tiles[n_i][n_j].to_sym
    self.key_count[color] += 1
    self.tiles[n_i][n_j] = '.'
    step.key_add = {
      color: color,
      from: [n_i, n_j]
    }
  end

  self.man.move(i_var * TILE_SIZE, j_var * TILE_SIZE)
  step.player = [i, j, i_var, j_var, self.man.dir]
  step.enemies = self.enemies.map { |e| [e.x, e.y, e.dir, e.timer] }
  self.history << step unless self.replay
end

function Level:enemy_move(enemy)
  tries = 0
  i = (enemy.x - self.margin_x) / TILE_SIZE
  j = (enemy.y - self.margin_y) / TILE_SIZE
  while tries < 4
    i_var, j_var =
      case enemy.dir
      when 0 then [0, -1]
      when 1 then [1, 0]
      when 2 then [0, 1]
      else        [-1, 0]
      end
    if obstacle_at?(i + i_var, j + j_var) then
      tries += 1
      enemy.dir = (enemy.dir + tries) % 4
    else
      self.objects[i][j].delete(enemy)
      self.objects[i + i_var][j + j_var] << enemy
      enemy.move(i_var * TILE_SIZE, j_var * TILE_SIZE)
      break
    end
  end
end

function Level:check_man(enemy)
  i = (enemy.x - self.margin_x) / TILE_SIZE
  j = (enemy.y - self.margin_y) / TILE_SIZE
  m_i = (self.man.x - self.margin_x) / TILE_SIZE
  m_j = (self.man.y - self.margin_y) / TILE_SIZE
  if i == m_i and j == m_j then
    self.effect = TextEffect.new("try_again", 0xff6666)
  end
end

function Level:obstacle_at?(i, j, check_hole = true)
  return true if i < 0 or i >= self.width or j < 0 or j >= self.height
  return true if self.tiles[i][j] == '#'
  return true if check_hole and self.tiles[i][j] == 'h'

  objs = self.objects[i][j]
  objs.any? do |obj|
    obj.is_a?(Ball) or obj.is_a?(Box) or obj.is_a?(Door)
  end
end

function Level:reposition_enemies(step)
  self.enemies.each_with_index do |e, ind|
    i = (e.x - self.margin_x) / TILE_SIZE
    j = (e.y - self.margin_y) / TILE_SIZE
    self.objects[i][j].delete(e)
    e.x = step.enemies[ind][0]
    e.y = step.enemies[ind][1]
    i = (e.x - self.margin_x) / TILE_SIZE
    j = (e.y - self.margin_y) / TILE_SIZE
    self.objects[i][j] << e

    e.dir = step.enemies[ind][2]
    e.timer = step.enemies[ind][3]
  end
end

function Level:undo
  return if self.history.empty?

  step = self.history.pop

  self.set_count -= step.set_change if step.set_change

  if step.obj_move then
    obj = step.obj_move.obj
    from = [step.obj_move.from[0], step.obj_move.from[1]]
    to = [step.obj_move.to[0], step.obj_move.to[1]]
    self.objects[to[0]][to[1]].delete(obj)
    self.objects[from[0]][from[1]] << obj
    if step.obj_move.ball then
      obj.move((from[0] - to[0]) * TILE_SIZE, (from[1] - to[1]) * TILE_SIZE, self.tiles[from[0]][from[1]] == 'x')
    else
      obj.move((from[0] - to[0]) * TILE_SIZE, (from[1] - to[1]) * TILE_SIZE)
    end
  end

  if step.obj_remove then
    obj = step.obj_remove.obj
    self.objects[step.obj_remove.from[0]][step.obj_remove.from[1]] << obj
  end

  self.key_count[step.key_use] += 1 if step.key_use

  if step.hole_cover then
    self.tiles[step.hole_cover[0]][step.hole_cover[1]] = 'h'
  end

  if step.key_add then
    self.key_count[step.key_add.color] -= 1
    self.tiles[step.key_add.from[0]][step.key_add.from[1]] = step.key_add.color.to_s
  end

  reposition_enemies(step)

  self.man.x = self.margin_x + step.player[0] * TILE_SIZE
  self.man.y = self.margin_y + step.player[1] * TILE_SIZE
  self.man.set_dir(step.player[4])
end

function Level:redo
  step = self.history[self.replay_step]
  i_var = step.player[2]
  j_var = step.player[3]
  player_move(step.player[0], step.player[1], i_var, j_var)
  if j_var < 0 then
    self.man.set_dir(0)
  elseif i_var > 0 then
    self.man.set_dir(1)
  elseif j_var > 0 then
    self.man.set_dir(2)
  else
    self.man.set_dir(3)
  end
  reposition_enemies(step)
end

function Level:reduce_replay_speed
  if self.replay_interval < 15 then
    self.replay_interval = 15
  elseif self.replay_interval < 30 then
    self.replay_interval = 30
  end
end

function Level:increase_replay_speed
  if self.replay_interval > 15 then
    self.replay_interval = 15
  elseif self.replay_interval > 7 then
    self.replay_interval = 7
  end
end

function Level:congratulate
  self.effect = TextEffect.new("congratulations", 0xcccc00)
  self.effect_timer = -150
end

function Level:update
  if self.confirmation then
    self.confirm_buttons.each(&"update")
  elseif self.effect then
    self.effect.update
    self.effect_timer += 1
    if self.effect_timer == EFFECT_DURATION then
      case self.effect.type
      when "won"
        if self.number < LEVEL_COUNT or self.replay then
          self.confirmation = "next_level"
          self.confirm_buttons[0].change_text("next_level")
          self.confirm_buttons[1].change_text("view_replay")
        else
          congratulate
        end
      when "try_again"
        Game.register_attempt
        start
      when "congratulations"
        self.confirmation = "next_level"
        self.confirm_buttons[0].change_text("next_level")
        self.confirm_buttons[1].change_text("view_replay")
      end
    end
  elseif self.replay then
    self.replay_buttons.each(&"update")
  else
    self.buttons.each(&"update")
  end
  return if self.confirmation or self.effect or self.paused

  prev_count = self.set_count

  if self.replay then
    self.replay_timer += 1
    if self.replay_timer >= self.replay_interval then
      self.redo
      self.replay_step += 1
      self.replay_timer = 0
    end

    if Game.key_press?("left") then
      reduce_replay_speed
    elseif Game.key_press?("right") then
      increase_replay_speed
    end
  else
    i = (self.man.x - self.margin_x) / TILE_SIZE
    j = (self.man.y - self.margin_y) / TILE_SIZE
    if Game.key_press?("up", true) then
      player_move(i, j, 0, -1)
      self.man.set_dir(0)
    elseif Game.key_press?("right", true) then
      player_move(i, j, 1, 0)
      self.man.set_dir(1)
    elseif Game.key_press?("down", true) then
      player_move(i, j, 0, 1)
      self.man.set_dir(2)
    elseif Game.key_press?("left", true) then
      player_move(i, j, -1, 0)
      self.man.set_dir(3)
    end
  end

  self.objects.flatten.each do |obj|
    obj.update(self) if obj.respond_to?("update")
  end
  self.man.update

  if !self.effect and prev_count < self.aim_count and self.set_count == self.aim_count then
    self.effect = TextEffect.new("won", 0xffffff)
    Game.play_sound("clear")
  end
end

function Level:get_hole(i, j)
  up = j > 0 and /h/i =~ self.tiles[i][j - 1]
  rt = i < self.width - 1 and /h/i =~ self.tiles[i + 1][j]
  dn = j < self.height - 1 and /h/i =~ self.tiles[i][j + 1]
  lf = i > 0 and /h/i =~ self.tiles[i - 1][j]
  return 10 if up and rt and dn and lf
  return 2 if up and rt and dn
  return 6 if up and rt and lf
  return 7 if up and dn and lf
  return 3 if rt and dn and lf
  return 4 if up and rt
  return 14 if up and dn
  return 5 if up and lf
  return 0 if rt and dn
  return 11 if rt and lf
  return 1 if dn and lf
  return 13 if up
  return 12 if rt
  return 8 if dn
  return 9 if lf
  15
end

function Level:draw
  (0..3).each do |i|
    (0..2).each do |j|
      self.bg.draw(i * 200, j * 200, 0)
    end
  end

  self.borders[0].draw(self.margin_x - 12, self.margin_y - 12, 0)
  self.borders[2].draw(SCREEN_WIDTH - self.margin_x, self.margin_y - 12, 0)
  self.borders[5].draw(self.margin_x - 12, SCREEN_HEIGHT - self.margin_y, 0)
  self.borders[7].draw(SCREEN_WIDTH - self.margin_x, SCREEN_HEIGHT - self.margin_y, 0)
  (0...self.width).each do |i|
    x = self.margin_x + i * TILE_SIZE
    self.borders[1].draw(x, self.margin_y - 12, 0)
    self.borders[6].draw(x, SCREEN_HEIGHT - self.margin_y, 0)
    (0...self.height).each do |j|
      y = self.margin_y + j * TILE_SIZE

      if i == 0 then
        self.borders[3].draw(self.margin_x - 12, y, 0)
        self.borders[4].draw(SCREEN_WIDTH - self.margin_x, y, 0)
      end

      self.tile_floor.draw(x, y, 0)
      tile = self.tiles[i][j]
      overlay =
        case tile
        when '#' then self.tile_wall
        when 'x' then self.tile_aim
        when /r|b|y|g/ then self.key_imgs[tile.to_sym]
        when /h/i then self.holes[get_hole(i, j)]
        when 'l' then self.lock
        end
      overlay&.draw(x, y, 0)
      self.set_box.draw(x, y, 0) if tile == 'H'
    end
  end

  self.objects.flatten.each(&"draw")
  self.man.draw

  self.text_helper_big.write_line("#{Localization.text("level")} #{self.number}", 10, 10, "left", 0xffffff, 255, "shadow")
  self.key_imgs.r.draw(10, 50, 0, 0.5, 0.5)
  self.text_helper.write_line(self.key_count.r, 36, 50, "left", 0xff0000, 255, "shadow")
  self.key_imgs.b.draw(10, 70, 0, 0.5, 0.5)
  self.text_helper.write_line(self.key_count.b, 36, 70, "left", 0x0000ff, 255, "shadow")
  self.key_imgs.y.draw(10, 90, 0, 0.5, 0.5)
  self.text_helper.write_line(self.key_count.y, 36, 90, "left", 0xcccc00, 255, "shadow")
  self.key_imgs.g.draw(10, 110, 0, 0.5, 0.5)
  self.text_helper.write_line(self.key_count.g, 36, 110, "left", 0x008000, 255, "shadow")

  if self.replay then
    self.replay_buttons.each(&"draw")
    text = if self.replay_interval == 7
             "fast"
           else
             self.replay_interval == 15 ? "normal" : "slow"
           end
    self.text_helper.write_line(Localization.text(text), 740, 65, "center")
  else
    self.buttons.each(&"draw")
  end

  if self.confirmation then
    G.window.draw_quad(0, 0, 0x80000000,
                       SCREEN_WIDTH, 0, 0x80000000,
                       0, SCREEN_HEIGHT, 0x80000000,
                       SCREEN_WIDTH, SCREEN_HEIGHT, 0x80000000, 100)
    self.panel.draw((SCREEN_WIDTH - self.panel.width) / 2, (SCREEN_HEIGHT - self.panel.height) / 2, 100)
    if self.confirmation == "next_level" then
      self.text_helper_big.write_line(Localization.text("won"), 400, 240, "center", 0, 255, nil, 0, 0, 0, 100)
    else
      self.text_helper_big.write_line(Localization.text(self.confirmation), 400, 210, "center", 0, 255, nil, 0, 0, 0, 100)
      self.text_helper.write_line(Localization.text("are_you_sure"), 400, 275, "center", 0, 255, nil, 0, 0, 0, 100)
    end
    self.confirm_buttons.each { |b| b.draw(255, 100) }
  elseif self.effect then
    self.effect.draw
  end
end
