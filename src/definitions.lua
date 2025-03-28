-- cell definition
cell = {
    x = 0,
    y = 0,
    -- tiles are only drawn once. Note that doors and other 'interactives' are entities.
    tile = nil, -- represented by a quad on the tileset. 
    index = nil, -- tile index. Most entities are unable to traverse solid tiles, but some can climb trees.
    trigger = nil, -- a special slot reserved to triggers (ie next-level triggers)
    occupant = nil, -- a player/npc or an entity with a 'Obstacle' component, occupying the cell
    entity = nil -- any entity that is not a 'occupant'. Limited to one per cell
}

-- entity definition. Entities are very simple containers for components!
Entity = Object:extend()

function Entity:new(id, tile, components, powers, name)
    -- can be either a player or a NPC component. Used to check groups
    self.controller = nil
    -- checked everytime an entity gets drawn, to see if it need to be eliminated
    self.alive = true
    -- an entity can only live inside cells. They also give x and y coords for drawing
    self.cell = {["cell"] = nil, ["grid_column"] = nil, ["grid_row"] = nil}
    -- obligatory, first CSV arg. Necessary to give a player context, since entities are universal containers
    self.id = id
    -- obligatory, second CSV arg. Necessary to draw entities to screen, even invisible ones (see design docs)
    self.tile = tile
    -- completely optional. This is where all entity components are defined, in an Object Aggregation fashion
    self.components = components or {}
    -- effects applied on Entity by other Entities powers. Activated before Entity turn
    self.effects = {} 
    -- completely optional. This is where all entity powers (abilities) are defined
    self.powers = powers or false
    -- completely optional. Used for Players names and special NPCs/objects
    self.name = name or id
    -- original tile. Storing it makes much easier and faster to change Entities appearence
    self.base_tile = tile
end

-- Selectors spawn Entities based on their arbitrary family and a die throw
Selector = Object:extend()

function Selector:new(input)
end

-- Spawners spawn Selectors
Spawner = Object:extend()

function Spawner:new(input)
end

-- Powers are built with Effects, and can be applied on self/target by Entities
-- they can be simple or complex and they range from damage to teleport and hallucination
Power = Object:extend()

function Power:new(input)
    -- power's name is already store in player's Entity.powers[power_name] = Power(input)
    -- self.effects is a table = {['effect_name'] = proper_input_table, ...}
    self.effects = {}

    -- assigning effect = own input table values
    for i, effect in ipairs(input) do
        -- first element of the table is power's name, skip
        if i ~= 1 then
            local effect_input = strings_separator(effect, "=", 1)

            -- checking effects validity, storing valid ones
            if EFFECTS_TABLE[effect_input[1]] then
                self.effects[effect_input[1]] = effect_input[2]
            else
                error_handler(effect_input[1] .. ": this effect doesn't exist, ignored")
            end
        end
    end
end

function Power:activate(target)
    -- for each effect in self.effects, call effect function and feed proper input
    for effect, input in pairs(self.effects) do
        EFFECTS_TABLE[effect](target, input)
    end
end

-- this stores lasting effects and their duration. Called by owner Entity just before turn
EffectTag = Object:extend()

function EffectTag:new(target, input, duration, func)
    self.target = target
    self.input = input
    self.duration = duration -- number of turns that the EffectTag will last
    self.func = func -- dedicated func to call, established by the parent Effect
end

function EffectTag:activate(target)
    self.duration = self.duration - 1
    self.func(self, self.target, self.input)
end

-- base state definition
BaseState = Object:extend()

function BaseState:new()
	function BaseState:init() end
	function BaseState:update() end
    function BaseState:refresh() end -- all the NON real-time graphics go here
	function BaseState:draw() end -- all the real-time graphics go here
	function BaseState:exit() end
    function BaseState:manage_input() end -- some states manage input in different ways
end



