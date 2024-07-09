-- This file is accessible to players for the customization of the game.

-- importing libs
Object = require "lib.classic.classic" -- simple class lib https://github.com/rxi/classic, MIT License
Event = require "lib.knife.event" -- useful micro-modules https://github.com/alexshi126/lua-knife, MIT License 
Timer = require "lib.knife.timer" -- useful micro-modules https://github.com/alexshi126/lua-knife, MIT License

-- importing necessary modules
require "math"
require "modding.mods"
require "src.globals"
require "src.components"
require "src.constants"
require "src.util"
require "src.definitions"

-- importing states
require "src.states.state_fatalerror"
require "src.states.state_play"
require "src.states.state_menu"
require "src.states.state_gameover"
require "src.states.state_credits"