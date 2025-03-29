require("lib.index")

local CONFIG_PATH = "config.soko"
local SCORES_PATH = "scores.soko"
local LANGUAGES = {"english", "portuguese", "spanish"}

local function save_scores()
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

local function save_config()
  local contents =
    (Game.full_screen and "+" or "-") .. ";" ..
    Game.language .. ";" ..
    Game.music_volume .. ";" ..
    Game.sound_volume .. ";" ..
    Game.last_level
  love.filesystem.write(CONFIG_PATH, contents)
end

Game = {}

function Game.load()
  Game.scores = {}
  if love.filesystem.getInfo(SCORES_PATH) then
    local contents = love.filesystem.read(SCORES_PATH)
    for entry_str in contents:gmatch("[^|]") do
      local entry = {}
      for score in entry:gmatch("[^;]") do
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
    save_config()
  end

  Localization.init(LANGUAGES[Game.language])
  print(Localization.text("lang_name"))
end

function Game.initialize()
  Game.font = Font.new("data/font/font.ttf", 20)
  Game.big_font = Font.new("data/font/font.ttf", 32)
  Game.controller = Presentation.new()
end
