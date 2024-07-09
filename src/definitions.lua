-- cell definition
cell = {
    x = 0,
    y = 0,
    -- tiles are only drawn once. Note that doors and other interactives are entities.
    tile = nil, -- represented by a quad on the tileset. 
    index = nil, -- tile index. Most entities are unable to traverse solid tiles, but some can climb trees.
    trigger = nil,
    occupant = nil,
    entity = nil
}

-- Entity definition. Entities are very simple containers for features!
Entity = Object:extend()

function Entity:new(id, tile, features, name)
    -- can be either a player or a NPC. Used to check groups
    self.controller = nil
    -- Checked everytime an Entity gets drawn, to see if it need to be eliminated
    self.alive = true
    -- Entities can only live inside cells. They also give x and y coords for drawing
    self.cell = {["cell"] = nil, ["grid_column"] = nil, ["grid_row"] = nil}
    -- Obligatory, first CSV arg. Necessary to give a player context, since they are universal containers
    self.id = id
    -- Obligatory, second CSV arg. Necessary to draw Entities to screen, even invisible ones (see design docs)
    self.tile = tile
    -- Completely optional. This is where all Entity Features are defined, in an Object Aggregation fashion
    self.features = features or {}
    -- Completely optional. Used for Players names and special NPCs/objects
    self.name = name or id
end

-- NOTE: components aren't there since they are wildly different and they are all simple Object:extensions

-- base state definition
BaseState = Object:extend()

function BaseState:new()
	function BaseState:init() end
	function BaseState:update() end
	function BaseState:draw() end
	function BaseState:exit() end
    function BaseState:manage_input() end -- States manage input in different ways
end



