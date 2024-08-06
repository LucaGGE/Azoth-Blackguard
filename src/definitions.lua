-- cell definition
cell = {
    x = 0,
    y = 0,
    -- tiles are only drawn once. Note that doors and other 'interactives' are entities.
    tile = nil, -- represented by a quad on the tileset. 
    index = nil, -- tile index. Most entities are unable to traverse solid tiles, but some can climb trees.
    trigger = nil, -- a special slot reserved to triggers (ie next-level triggers)
    occupant = nil, -- a player/npc or an entity with a 'Bulky' feature, occupying the cell
    entity = nil -- any entity that is not a 'occupant'. Limited to one per cell
}

-- entity definition. Entities are very simple containers for features!
Entity = Object:extend()

function Entity:new(id, tile, features, name)
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
    -- completely optional. This is where all entity features are defined, in an Object Aggregation fashion
    self.features = features or {}
    -- completely optional. Used for Players names and special NPCs/objects
    self.name = name or id
end

-- NOTE: components aren't there since they are wildly different and they are all simple Object:extensions

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



