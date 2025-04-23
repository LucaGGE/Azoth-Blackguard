-- cells are the grid's nodes and store all types of Entities and physics
cell = {
    x = 0,
    y = 0,
    tile = nil, -- represented by a quad on the tileset
    index = nil, -- num translating to a quad position on tileset
    pawn = nil, -- single Player/NPC occupying the cell
    entity = nil -- single Entity that is not a 'pawn'
}

-- entity definition. Entities are very simple containers for components!
Entity = Object:extend()

function Entity:new(id, tile, components, powers, name)
    -- can be either a player or a NPC component. Used to check groups
    self.pilot = nil
    -- checked everytime an entity gets drawn, to see if it need to be eliminated
    self.alive = true
    -- Entities live inside cells. They also give x and y coords for drawing
    self.cell = {["cell"] = nil, ["grid_col"] = nil, ["grid_row"] = nil}
    -- first CSV arg. Essential to identify Entity, since they are just containers
    self.id = id
    -- second CSV arg. All visibile and invisible Entities are drawn on screen
    self.tile = tile
    -- optional. In an OOPBA fashion, this is how Entities are defined
    self.comp = components or {}
    -- effects applied on Entity by others powers. Activated before Entity turn
    self.effects = {} 
    -- optional. This is where all entity powers (abilities) are defined
    self.powers = powers or false
    -- optional. Useful for Players names and special NPCs/objects
    -- NOTE: if left blank, name will be equal to id
    self.name = name or id
    -- original tile. Storing it makes it easier to restore Entity appearence
    self.og_tile = tile
end

-- Selectors spawn Entities based on arbitrary family/group and a die throw
Selector = Object:extend()

function Selector:new(id, die_set, elements)
    self.id = id
    self.die_set = die_set
    self.elements = elements
end

-- Spawners spawn Selectors
Spawner = Object:extend()

function Spawner:new(input)
end

-- Powers are groups of Effects, and can be applied on self/target by Entities
-- they can be simple or complex and they range from damage to hallucination
Power = Object:extend()

function Power:new(input)
    -- power's name is stored as Entity.powers[power_name] = Power(input)
    -- self.effects is a table = {['effect_name'] = proper_input_table, ...}
    self.effects = {}

    -- assigning effect = own input table values
    for i, effect in ipairs(input) do
        -- first element of the table is power's name, skip
        if i ~= 1 then
            local effect_target_input = str_slicer(effect, "=", 1)
            local effect_target = str_slicer(effect_target_input[1], "_", 1)
            local effect = effect_target[1]
            local suffix = effect_target[2]
            local value = effect_target_input[2]
            local valid_suffix = false

            -- check that a target suffix was fed
            if not suffix then
                print("No suffix given to effect: " .. effect .. ", setting it to owner")
                effect_target_input[1] = effect .. "_owner"
                goto continue
            end

            -- checking suffix validity
            if suffix == "owner" or suffix == "activator" or suffix == "target" then
                valid_suffix = true
            end

            if not valid_suffix then
                print("Invalid suffix given to effect: " .. effect .. ", setting it to owner")
                effect_target_input[1] = effect .. "_owner"
            end

            ::continue::

            -- checking effects validity, storing valid ones
            if EFFECTS_TABLE[effect] then
                self.effects[effect_target_input[1]] = value
            else
                error_handler(effect .. ": this effect doesn't exist, ignored")
            end
        end
    end
end

function Power:activate(owner, target, activator)
    -- decision table translating suffix to actual affected Entity
    local D_TABLE = {
        ["activator"] = activator,
        ["owner"] = owner,
        ["target"] = target
    }

    -- for each effect in self.effects, call effect function and feed proper input
    for effect_suffix, input in pairs(self.effects) do
        local effect_target = str_slicer(effect_suffix, "_", 1)
        local effect = effect_target[1]
        local target = effect_target[2]

        -- suffixes are activator, target and owner. They establish affected Entity
        EFFECTS_TABLE[effect](D_TABLE[target], input, owner)
    end
end

-- stores lasting effects & their duration. Called by owner Entity just before turn
EffectTag = Object:extend()

function EffectTag:new(target, input, duration, func)
    self.target = target
    self.input = input
    self.duration = duration -- number of turns that the EffectTag will last
    self.func = func -- dedicated func to call, established by the parent Effect
end

function EffectTag:activate()
    local success

    -- target may have died from a prior effect on stack, check if alive
    if not self.target.alive then
        return false
    end

    self.duration = self.duration - 1

    success = self.func(self.target, self.input)

    -- if target is immune to EffectTag, then set its duration to 0
    if not success then self.duration = 0 end
end

-- effects influence entities in a variety of ways and are assigned by 'Power' comp.
-- Effects are validated by EFFECTS_TABLE and executed by apply_effect() func.
Effect = Object:extend()
function Effect:new(input_effects)
    self.active_effects = {}

    -- immediately add optional effects and effect immunities on comp creation
    self:add(input_effects)
end

-- base state definition
BaseState = Object:extend()

function BaseState:new()
	function BaseState:init() end
	function BaseState:update() end
    function BaseState:refresh() end -- all the NON real-time graphics go here
	function BaseState:draw() end -- all the real-time graphics go here
	function BaseState:exit() end
    function BaseState:manage_input() end -- states manage input in different ways
end