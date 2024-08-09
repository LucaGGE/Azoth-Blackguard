--[[
    This file allows you to modify the game as you see fit! All values are initally set to 'nil',
    that means they are empty, or false. Just change this values as you wish, and reset the to 'nil'
    if you want the game to go back to its defaults.
    Have fun!
]]--

-- this is a table that gathers all your modded values. DO NOT TOUCH!
mod = {
    -- variable containing the path to your modified CSV files (change \ symbols with / symbols!)
    PATH_TO_CSV = false,

    -- the final image size multiplier: think of zooming what you see in the game screen. 2 by default
    IMAGE_SIZE_MULTIPLIER = false,

    -- variable containing the path to your tileset
    PATH_TO_TILESET = false,

    -- the individual tile size, as drawn in the tileset. By default, the game uses 20x20 pixels tiles
    TILE_SIZE = false,

    -- lets you change the default background color in RGB format to better fit your tileset palette
    BKG_R = false,
    BKG_G = false,
    BKG_B = false,

    -- title of the game (put it in quotes, i.e. "My Game")
    GAME_TITLE = false,

    -- font sizes (to change the fonts themselves, just change them in the 'font' folder)
    FONT_SIZE_TITLE = false,
    FONT_SIZE_SUBTITLE = false,
    FONT_SIZE_DEFAULT = false,
    -- padding size (the space used to position strings inside the window)
    PADDING = false,

    -- this lets you choose if maps are loaded sequentially (false) or generated (true)
    GENERATION = false,

    -- lets you access the game's debugging console. Use "false" or "true"
    DEBUG_CONSOLE = true,
}