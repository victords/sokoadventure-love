require("lib.index")
require("src.constants")
require("src.presentation")
require("src.menu")
require("src.level")

local CONFIG_PATH = "config.soko"
local SCORES_PATH = "scores.soko"
local LANGUAGES = {"english", "portuguese", "spanish"}

Game = {}

function Game.load()
  Game.scores = {}
  if love.filesystem.getInfo(SCORES_PATH) then
    local contents = love.filesystem.read(SCORES_PATH)
    for entry_str in contents:gmatch("[^|]+") do
      local entry = {}
      for score in entry_str:gmatch("[^;]+") do
        table.insert(entry, tonumber(score))
      end
      table.insert(Game.scores, entry)
    end
  end

  if love.filesystem.getInfo(CONFIG_PATH) then
    local contents = love.filesystem.read(CONFIG_PATH)
    local iter, state = contents:gmatch("[^;]+")
    Game.full_screen = iter(state) == '+'
    Game.language = tonumber(iter(state))
    Game.music_volume = tonumber(iter(state))
    Game.sound_volume = tonumber(iter(state))
    Game.last_level = tonumber(iter(state))
  else
    Game.full_screen = true
    Game.language = 1
    Game.music_volume = 10
    Game.sound_volume = 10
    Game.last_level = 1
    Game.save_config()
  end

  Game.font = Res.font("font", 20)
  Game.big_font = Res.font("font", 32)
  print(Game.font.height, Game.big_font.height)
  Game.controller = Presentation.new()

  Localization.init(LANGUAGES[Game.language])
  KB.held_delay = 5
  love.window.setFullscreen(Game.full_screen)
end

function Game.play_song(id)
  local song = Res.song(id)
  if Song.current == song then return end
  song:play(Game.music_volume * 0.1)
end

function Game.play_sound(id)
  Res.sound(id):play(Game.sound_volume * 0.1)
end

function Game.key_press(id, held)
  local keys
  if id == "up" then
    keys = {"up", "gp1_up"}
  elseif id == "right" then
    keys = {"right", "gp1_right"}
  elseif id == "down" then
    keys = {"down", "gp1_down"}
  elseif id == "left" then
    keys = {"left", "gp1_left"}
  elseif id == "confirm" then
    keys = {"q", "gp1_a"}
  elseif id == "cancel" then
    keys = {"w", "gp1_b"}
  elseif id == "undo" then
    keys = {"z", "gp1_x"}
  elseif id == "restart" then
    keys = {"r", "gp1_y"}
  elseif id == "quit" then
    keys = {"escape", "gp1_back"}
  elseif id == "pause" then
    keys = {"space", "gp1_start"}
  end
  return KB.pressed(keys[1]) or KB.pressed(keys[2]) or
    held and (KB.held(keys[1]) or KB.held(keys[2]))
end

function Game.toggle_gamepad(connected)
  if Game.controller.toggle_gamepad then
    Game.controller:toggle_gamepad(connected)
  end
end

function Game.open_menu()
  Game.controller = Menu.new()
end

function Game.start(level)
  Game.current_score = {
    start_level = level,
    attempts = 1
  }
  Game.controller = Level.new(level)
end

function Game.register_attempt()
  Game.current_score.attempts = Game.current_score.attempts + 1
end

function Game.save_scores()
  local contents = ""
  for i, entry in ipairs(Game.scores) do
    for j, score in ipairs(entry) do
      contents = content .. score
      if j < #entry then content = content .. ";" end
    end
    if i < #Game.scores then content = content .. "|" end
  end
  love.filesystem.write(SCORES_PATH, contents)
end

function Game.save_config()
  local contents =
    (Game.full_screen and "+" or "-") .. ";" ..
    Game.language .. ";" ..
    Game.music_volume .. ";" ..
    Game.sound_volume .. ";" ..
    Game.last_level
  love.filesystem.write(CONFIG_PATH, contents)
end

function Game.toggle_full_screen()
  Game.full_screen = not Game.full_screen
  love.window.setFullscreen(Game.full_screen)
end

function Game.next_language()
  Game.language = (Game.language % #LANGUAGES) + 1
  Localization.set_language(LANGUAGES[Game.language])
end

function Game.change_music_volume(delta)
  Game.music_volume = Game.music_volume + delta
  if Game.music_volume < 0 then Game.music_volume = 0 end
  if Game.music_volume > 10 then Game.music_volume = 10 end
  if Song.current then Song.current:set_volume(Game.music_volume * 0.1) end
end

function Game.change_sound_volume(delta)
  Game.sound_volume = Game.sound_volume + delta
  if Game.sound_volume < 0 then Game.sound_volume = 0 end
  if Game.sound_volume > 10 then Game.sound_volume = 10 end
end

function Game.quit()
  Game.current_score.end_level = Game.controller.number
  Game.update_scores()
  Game.open_menu()
end

function Game.next_level()
  local current = Game.controller.number
  if current < LEVEL_COUNT then
    if Game.last_level <= current then
      Game.last_level = Game.last_level + 1
      Game.save_config()
    end
    Game.controller = Level.new(current + 1)
  else
    Game.current_score.end_level = LEVEL_COUNT + 1
    Game.update_scores()
    Game.quit()
  end
end

function Game.update_scores()
  if Game.current_score.start_level == Game.current_score.end_level then
    return
  end

  local inserted = false
  for i, s in ipairs(Game.scores) do
    if Game.current_score.end_level > s[2] or
       Game.current_score.end_level == s[2] and Game.current_score.start_level < s[1] or
       Game.current_score.end_level == s[2] and Game.current_score.start_level == s[1] and Game.current_score.attempts < s[3] then
      table.insert(Game.scores, i, {Game.current_score.start_level, Game.current_score.end_level, Game.current_score.attempts})
      inserted = true
      break
    end
  end
  if #Game.scores < 5 and not inserted then
    table.insert(Game.scores, {Game.current_score.start_level, Game.current_score.end_level, Game.current_score.attempts})
  end
  if #Game.scores > 5 then
    table.remove(Game.scores)
  end

  Game.save_scores()
end

function Game.update()
  KB.update()
  Mouse.update()
  Game.controller:update()
end

function Game.draw()
  Game.controller:draw()
end
