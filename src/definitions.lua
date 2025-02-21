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

function Entity:new(id, tile, components, name)
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
    -- completely optional. This is where all entity powers (abilities) are defined
    self.powers = powers or {}
    -- completely optional. Used for Players names and special NPCs/objects
    self.name = name or id
end

-- Powers are built with Effects, and can be applied on self/target by Entities
-- they can be simple or complex and they range from damage to teleport and hallucination
Power = Object:extend()

function Power:new(string, inputs, input_effects)
    -- string printed on console when power is used
    self.string = string or error_handler("Power error: no string")
    -- self.effects is a table = {['effect_name'] = proper_input_table, ...}
    self.effects = {}
    -- input_effects is a 3D table = {[1] = {1d1, 2d3, 1d6}, [2] = {2d4, 1d2}, ...}
    -- with this loop, each effect is assigned the proper table of input values
    for i, effect in ipairs(input_effects) do
        self.effects[effect] = inputs[i]
    end
end

function Power:activate(target)
    console_event(self.string)
    -- for each effect in self.effects, call effect function and feed proper input
    for effect,input in pairs(self.effects) do
        EFFECTS_TABLE[effect](target, input)
    end
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



