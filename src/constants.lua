-- variable containing the path to the necessary CSV files
-- the two current local paths I use are "F:/Development/Dev_Games/GOBLET/source/azoth!_blackguard/modding/" or "C:/Users/foxre/"
-- you'll need to modify these to your local path since the system, to date, cannot find other than LUA files in the relative path
PATH_TO_CSV = mod.path_to_csv or "F:/Development/Dev_Games/GOBLET/source/azoth!_blackguard/modding/"

GAME_TAG = "Azoth! Blackguard"
GAME_TITLE = type(mod.game_title) == "string" and mod.game_title or "Descent into the Grim Path"

--[[
    Pay attention to tiles_features_pairs. It will store tile index = tile type,
    to easily check how to interact with a specific tile. Also note that each tile can 
    have one 'physical state' at a given time, but it can change anytime.
    Tile indexes without a type will give a 'nil' value, and since the can_transverse
    var in Movable:move_entity func is false by default, they won't allow for any movement.
]]
TILES_FEATURES_PAIRS = {["empty"] = "ground"} -- empty cells are considered ground

-- all the valid tiles features for TILES_VALID_FEATURES table (see pairings in components.lua)
TILES_VALID_FEATURES = {
    ["liquid"] = true,
    ["climbable"] = true,
    ["void"] = true,
    ["solid"] = true,
    ["ground"] = true
}

-- list of all entity blueprints registered from dedicated CSV file
BLUEPRINTS_LIST = {}

-- duration of normal tweening animations
TWEENING_TIME = 0.25

-- sizes relative to all available fonts
FONT_SIZE_TITLE = mod.font_size_title or 60
FONT_SIZE_TAG = mod.font_size_tag or 45
FONT_SIZE_SUBTITLE = mod.font_size_subtitle or 35
FONT_SIZE_DEFAULT = mod.font_size_default or 30
FONT_SIZE_ERROR = mod.font_size_default or 24
PADDING = mod.padding or 32

-- sizes relative to tiles
TILE_SIZE = mod.TILE_SIZE or 20 -- used for cell size/tileset slicing.
HALF_TILE = (mod.TILE_SIZE or 20) / 2 -- used when centering the screen on player
SIZE_MULTIPLIER = mod.IMAGE_SIZE_MULTIPLIER or 2

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
    ["tag"] = love.graphics.newFont("fonts/GothicPixels.ttf", FONT_SIZE_TAG),
    ["logo"] = love.graphics.newFont("fonts/GothicPixels.ttf", FONT_SIZE_DEFAULT),
    ["title"] = love.graphics.newFont("fonts/GothicPixels.ttf", FONT_SIZE_TITLE),
    ["subtitle"] = love.graphics.newFont("fonts/alagard.ttf", FONT_SIZE_SUBTITLE),
    ["ui"] = love.graphics.newFont("fonts/alagard.ttf", FONT_SIZE_DEFAULT),
    ["error"] = love.graphics.newFont("fonts/BitPotion.ttf", FONT_SIZE_ERROR),
    ["console"] = love.graphics.newFont("fonts/VeniceClassic.ttf", FONT_SIZE_DEFAULT),
}

BORDERS = {
    [1] = {},
    [2] = {},
    [3] = {}
}

--[[
    All the valid components for COMPONENTS_INTERFACE function.
    NOTE: this table requires components.lua to be required first.
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