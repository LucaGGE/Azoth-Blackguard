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

-- this resized everything to better adapt to different screen sizes
SIZE_MULT = mod.IMAGE_SIZE_MULTIPLIER or 2

-- sizes relative to tiles
TILE_SIZE = mod.TILE_SIZE or 20 -- used for cell size/tileset slicing
HALF_TILE = TILE_SIZE / 2 -- used when centering the screen on player

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
    ["sfx_pickup"] = love.audio.newSource("sfx/sfx_pickup.ogg", "static"),
    ["sfx_equip"] = love.audio.newSource("sfx/sfx_equip.ogg", "static"),
    ["sfx_unequip"] = love.audio.newSource("sfx/sfx_unequip.ogg", "static"),
    ["sfx_cursed"] = love.audio.newSource("sfx/sfx_cursed.ogg", "static"),
    ["sfx_mace_light"] = love.audio.newSource("sfx/sfx_mace_light.ogg", "static"),
    ["sfx_mace_heavy"] = love.audio.newSource("sfx/sfx_mace_heavy.ogg", "static"),
    ["sfx_miss"] = love.audio.newSource("sfx/sfx_miss.ogg", "static"),
    ["sfx_gold"] = love.audio.newSource("sfx/sfx_gold.wav", "static"),
    ["sfx_lever"] = love.audio.newSource("sfx/sfx_lever.ogg", "static"),
    ["sfx_door"] = love.audio.newSource("sfx/sfx_door.ogg", "static"),
    ["sfx_unlock"] = love.audio.newSource("sfx/sfx_unlock.ogg", "static"),
    ["sfx_sword"] = love.audio.newSource("sfx/sfx_sword.ogg", "static"),
    ["sfx_crab"] = love.audio.newSource("sfx/sfx_crab.ogg", "static"),
    ["sfx_death"] = love.audio.newSource("sfx/sfx_death.ogg", "static"),
    ["sfx_death_blu"] = love.audio.newSource("sfx/sfx_death_blu.ogg", "static"),
    ["sfx_death_sla"] = love.audio.newSource("sfx/sfx_death_sla.ogg", "static"),
    ["sfx_death_pie"] = love.audio.newSource("sfx/sfx_death_pie.ogg", "static"),
    ["sfx_death_ble"] = love.audio.newSource("sfx/sfx_death_ble.ogg", "static")
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
    ["locked"] = Locked,
    ["shooter"] = Shooter,
    ["stack"] = Stack,
    ["mutation"] = Mutation
}

-- valid effects for the that can be applied to Entities
EFFECTS_TABLE = {
    ["poison"] = poison,
    ["slash"] = slash,
    ["bludgeon"] = bludgeon,
    ["pierce"] = pierce,
    ["action"] = action_str,
    ["event"] = event_effect,
    ["statgold"] = stat_gold,
    ["sfx"] = sfx_play,
    ["tileswitch"] = tile_switch,
    ["tilechange"] = tile_change,
    ["tilerestore"] = tile_restore,
    ["physchange"] = phys_change,
    ["cmd"] = cmd_func,
    ["mutationapply"] = mutation_apply,
    ["mutationremove"] = mutation_remove
}