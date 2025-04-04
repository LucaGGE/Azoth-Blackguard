--[[
    Variable containing the path to the necessary CSV files.
    The two current local paths I use are:
    "F:/Development/Dev_Games/GOBLET/source/azoth!_blackguard/modding/" or "C:/Users/foxre/".
    You'll need to modify these to your local path since the system, to date, cannot
    find other than LUA files in the relative path.
]]--
FILES_PATH = mod.FILES_PATH or "F:/Development/Dev_Games/GOBLET/source/azoth!_blackguard/modding/"

GAME_LOGO = "Azoth! Blackguard"
local game_title = "Descent into the Grim Path"
GAME_TITLE = type(mod.game_title) == "string" and mod.game_title or game_title
-- garbage collect unnecessary variable
game_title = nil

--[[
    Pay attention to TILES_PHYSICS. It will store tile index = tile type, to easily
    check how to interact with a specific tile. Also note that each tile can have
    one 'physical state' at a given time, but it can change anytime. Tile indexes
    without a type will give a 'nil' value, and since the can_transverse var in
    Movable:move_entity func is false by default, they won't allow for any movement.
]]
TILES_PHYSICS = {["empty"] = "ground"} -- empty cells are considered ground

-- valid values for VALID_PHYSICS table (see pairings in components.lua)
VALID_PHYSICS = {
    ["difficult"] = true,
    ["liquid"] = true,
    ["climbable"] = true,
    ["void"] = true,
    ["solid"] = true,
    ["ground"] = true
}

-- list of all entity blueprints registered from dedicated CSV file
BP_LIST = {}
-- graphics sets
TILESET = love.graphics.newImage(mod.PATH_TO_TILESET or "graphics/tileset.png")
FRAMESET = love.graphics.newImage(mod.PATH_TO_FRAMESET or "graphics/borders.png")

-- duration of normal tweening animations
TWEENING_TIME = 0.25

-- sizes relative to all available fonts
SIZE_MAX = mod.SIZE_MAX or 60
SIZE_SUB = mod.SIZE_SUB or 35
SIZE_TAG = mod.SIZE_TAG or 45
SIZE_DEF = mod.SIZE_DEF or 30
SIZE_ERR = mod.SIZE_DEF or 24
PADDING = mod.padding or 32

-- sizes relative to tiles
TILE_SIZE = mod.TILE_SIZE or 20 -- used for cell size/tileset slicing.
HALF_TILE = (mod.TILE_SIZE or 20) / 2 -- used when centering the screen on player
SIZE_MULT = mod.IMAGE_SIZE_MULTIPLIER or 2

MUSIC = {
    ["swamp"] = love.audio.newSource("sfx/st_swamp.ogg", "static"),
    ["gameover_sting"] = love.audio.newSource("sfx/sting_gameover.ogg", "static"),
    ["gameover"] = love.audio.newSource("sfx/st_gameover.ogg", "static"),
    ["menu"] = love.audio.newSource("sfx/st_menu.ogg", "static"),
}

SOUNDS = {
    ["ground"] = love.audio.newSource("sfx/step_ground.ogg", "static"),
    ["solid"] = love.audio.newSource("sfx/step_solid.ogg", "static"),
    ["climbable"] = love.audio.newSource("sfx/step_climbable.ogg", "static"),
    ["void"] = love.audio.newSource("sfx/step_tricky.ogg", "static"),
    ["difficult"] = love.audio.newSource("sfx/step_tricky.ogg", "static"),
    ["liquid"] = love.audio.newSource("sfx/step_liquid.ogg", "static"),
    ["wait"] = love.audio.newSource("sfx/step_wait.wav", "static"),
    ["button_select"] = love.audio.newSource("sfx/button_select.wav", "static"),
    ["button_switch"] = love.audio.newSource("sfx/button_switch.wav", "static"),
    ["type_input"] = love.audio.newSource("sfx/type_input.wav", "static"),
    ["type_backspace"] = love.audio.newSource("sfx/type_backspace.wav", "static"),
    ["type_nil"] = love.audio.newSource("sfx/type_nil.wav", "static"),
    ["puzzle_success"] = love.audio.newSource("sfx/puzzle_success.wav", "static"),
    ["puzzle_fail"] = love.audio.newSource("sfx/puzzle_fail.wav", "static"),
    ["hit_blow"] = love.audio.newSource("sfx/hit_blow.ogg", "static"),
    ["hit_miss"] = love.audio.newSource("sfx/hit_miss.wav", "static"),
    ["sfx_gold"] = love.audio.newSource("sfx/sfx_gold.wav", "static"),
}

FONTS = {
    ["tag"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE_TAG),
    ["logo"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE_SUB),
    ["title"] = love.graphics.newFont("fonts/GothicPixels.ttf", SIZE_MAX),
    ["subtitle"] = love.graphics.newFont("fonts/alagard.ttf", SIZE_SUB),
    ["ui"] = love.graphics.newFont("fonts/alagard.ttf", SIZE_DEF),
    ["error"] = love.graphics.newFont("fonts/BitPotion.ttf", SIZE_ERR),
    ["console"] = love.graphics.newFont("fonts/VeniceClassic.ttf", SIZE_DEF),
}

BORDERS = {
    [1] = {},
    [2] = {},
    [3] = {}
}

--[[
    All the valid components for COMPONENTS_INTERFACE function.
    NOTE: this table requires components.lua to be required before constants.lua.
    Still, components can use constants.lua variables since they're called inside
    the classes and not executed until main.lua has finished loading everything.
]]
COMPONENTS_TABLE = {
    ["player"] = Player,
    ["npc"] = Npc,
    ["stats"] = Stats,
    ["profile"] = Profile,
    ["trigger"] = Trigger,
    ["pickup"] = Pickup,
    ["usable"] = Usable,
    ["obstacle"] = Obstacle,
    ["movable"] = Movable,
    ["exit"] = Exit,
    ["invisible"] = Invisible,
    ["inventory"] = Inventory,
    ["slots"] = Slots,
    ["equipable"] = Equipable,
    ["sealed"] = Sealed,
    ["secret"] = Secret,
    ["description"] = Description,
    ["linked"] = Linked,
    ["key"] = Key,
    ["locked"] = Locked
}

-- valid effects for the that can be applied to Entities
EFFECTS_TABLE = {
    ["poison"] = poison,
    ["slash"] = slash,
    ["str"] = str_effect,
    ["statgold"] = stat_gold,
    ["sfx"] = sfx_play,
    ["tileswitch"] = tile_switch,
    ["tilechange"] = tile_change,
    ["tilerestore"] = tile_restore,
    ["physchange"] = phys_change
}