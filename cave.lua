-- cave.lua
local Cave = {}
Cave.__index = Cave

local TILE_SOLID = 0
local TILE_FLOOR = 1

function Cave.new(seed, width, height)
    local self = setmetatable({}, Cave)
    math.randomseed(seed)

    self.seed   = seed
    self.width  = width
    self.height = height
    self.tiles  = {}
    self.revealed = {}

    -- Fill with solid rock
    for y = 1, height do
        self.tiles[y]    = {}
        self.revealed[y] = {}
        for x = 1, width do
            self.tiles[y][x]    = TILE_SOLID
            self.revealed[y][x] = false
        end
    end

    self:_drunkWalk()
    self:_smooth(3)

    return self
end

function Cave:_carve(x, y, radius)
    radius = radius or 1
    for dy = -radius, radius do
        for dx = -radius, radius do
            local nx, ny = x + dx, y + dy
            if nx >= 2 and nx <= self.width-1 and ny >= 2 and ny <= self.height-1 then
                self.tiles[ny][nx] = TILE_FLOOR
            end
        end
    end
end

function Cave:nearestFloor(x, y)
    if self:get(x, y) == TILE_FLOOR then return x, y end
    for r = 1, 20 do
        for dy = -r, r do
            for dx = -r, r do
                local nx, ny = x+dx, y+dy
                if self:get(nx, ny) == TILE_FLOOR then
                    return nx, ny
                end
            end
        end
    end
    return x, y  -- fallback
end

function Cave:_drunkWalk()
    local cx = math.floor(self.width  / 2)
    local cy = math.floor(self.height / 2)

    local dirs = { {0,-1}, {0,1}, {-1,0}, {1,0} }

    -- Main walker — long, deep
    local function walk(startX, startY, steps, radius, bias)
        local x, y = startX, startY
        local lastDir = nil
        for _ = 1, steps do
            self:_carve(x, y, radius)
            -- bias toward continuing in same direction for more organic tunnels
            local dir
            if lastDir and math.random() < bias then
                dir = lastDir
            else
                dir = dirs[math.random(#dirs)]
            end
            lastDir = dir
            x = math.max(2, math.min(self.width-1,  x + dir[1]))
            y = math.max(2, math.min(self.height-1, y + dir[2]))
        end
        return x, y  -- return end position for branching
    end

    -- Primary tunnel — deep, biased strongly forward
    local ex, ey = walk(cx, cy, 2000, 1, 0.75)

    -- Branch tunnels off random points along the main path
    for _ = 1, 6 do
        local bx = math.random(10, self.width  - 10)
        local by = math.random(10, self.height - 10)
        -- only branch from carved floor
        if self.tiles[by][bx] == TILE_FLOOR then
            walk(bx, by, math.random(300, 700), 1, 0.6)
        end
    end

    -- A couple of wider caverns
    for _ = 1, 4 do
        local rx = math.random(5, self.width  - 5)
        local ry = math.random(5, self.height - 5)
        if self.tiles[ry][rx] == TILE_FLOOR then
            self:_carve(rx, ry, math.random(2, 4))
        end
    end

    -- Record start position
    self.startX = cx
    self.startY = cy
    for dy = -2, 2 do
        for dx = -2, 2 do
            local nx = self.startX + dx
            local ny = self.startY + dy
            if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                self.tiles[ny][nx] = TILE_FLOOR
            end
        end
    end
end

function Cave:_smooth(passes)
    for _ = 1, passes do
        local next = {}
        for y = 1, self.height do
            next[y] = {}
            for x = 1, self.width do
                local neighbors = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local nx, ny = x+dx, y+dy
                        if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                            if self.tiles[ny][nx] == TILE_FLOOR then
                                neighbors = neighbors + 1
                            end
                        end
                    end
                end
                -- if 5+ of 9 neighbors are floor, become floor
                next[y][x] = (neighbors >= 5) and TILE_FLOOR or self.tiles[y][x]
            end
        end
        self.tiles = next
    end
end

function Cave:reveal(x, y, radius)
    radius = radius or 3
    for dy = -radius, radius do
        for dx = -radius, radius do
            local nx, ny = x+dx, y+dy
            if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                if dx*dx + dy*dy <= radius*radius then
                    self.revealed[ny][nx] = true
                end
            end
        end
    end
end

function Cave:get(x, y)
    if not self.infinite then
        if x < 1 or x > self.width or y < 1 or y > self.height then
            return TILE_SOLID
        end
        return self.tiles[y][x]
    else
        local cx, cy, lx, ly = self:_worldToChunk(x, y)
        self:_generateChunk(cx, cy)
        local key = self:_chunkKey(cx, cy)
        return self.chunks[key][ly][lx]
    end
end

function Cave:isRevealed(x, y)
    if not self.infinite then
        if x < 1 or x > self.width or y < 1 or y > self.height then
            return false
        end
        return self.revealed[y][x]
    else
        return self.revealed[x .. "," .. y] or false
    end
end

function Cave:reveal(x, y, radius)
    radius = radius or 3
    for dy = -radius, radius do
        for dx = -radius, radius do
            local nx, ny = x+dx, y+dy
            if dx*dx + dy*dy <= radius*radius then
                if not self.infinite then
                    if nx >= 1 and nx <= self.width and ny >= 1 and ny <= self.height then
                        self.revealed[ny][nx] = true
                    end
                else
                    self.revealed[nx .. "," .. ny] = true
                    -- make sure the chunk exists so probes don't hit nil
                    local cx, cy = self:_worldToChunk(nx, ny)
                    self:_generateChunk(cx, cy)
                end
            end
        end
    end
end

Cave.SOLID = TILE_SOLID
Cave.FLOOR = TILE_FLOOR

local CHUNK_SIZE = 32

function Cave.newInfinite(seed)
    local self = setmetatable({}, Cave)
    math.randomseed(seed)

    self.seed     = seed
    self.width    = math.huge
    self.height   = math.huge
    self.infinite = true
    self.chunks   = {}   -- keyed by "cx,cy"
    self.revealed = {}   -- keyed by "x,y"

    self.startX = 0
    self.startY = 0

    return self
end

function Cave:_chunkKey(cx, cy)
    return cx .. "," .. cy
end

function Cave:_generateChunk(cx, cy)
    local key = self:_chunkKey(cx, cy)
    if self.chunks[key] then return end

    local chunk = {}
    for y = 1, CHUNK_SIZE do
        chunk[y] = {}
        for x = 1, CHUNK_SIZE do
            chunk[y][x] = TILE_SOLID
        end
    end
    self.chunks[key] = chunk

    -- Drunk walk within and around this chunk
    local dirs = { {0,-1}, {0,1}, {-1,0}, {1,0} }
    local wx = math.random(1, CHUNK_SIZE)
    local wy = math.random(1, CHUNK_SIZE)

    -- Seed per-chunk so same seed always produces same chunk
    local chunkSeed = self.seed + cx * 73856093 + cy * 19349663
    math.randomseed(chunkSeed)

    for _ = 1, CHUNK_SIZE * CHUNK_SIZE * 0.45 do
        if wx >= 1 and wx <= CHUNK_SIZE and wy >= 1 and wy <= CHUNK_SIZE then
            chunk[wy][wx] = TILE_FLOOR
        end
        local dir = dirs[math.random(#dirs)]
        wx = wx + dir[1]
        wy = wy + dir[2]
        wx = math.max(1, math.min(CHUNK_SIZE, wx))
        wy = math.max(1, math.min(CHUNK_SIZE, wy))
    end
end

function Cave:_worldToChunk(x, y)
    local cx = math.floor(x / CHUNK_SIZE)
    local cy = math.floor(y / CHUNK_SIZE)
    local lx = x - cx * CHUNK_SIZE
    local ly = y - cy * CHUNK_SIZE
    if lx == 0 then lx = CHUNK_SIZE; cx = cx - 1 end
    if ly == 0 then ly = CHUNK_SIZE; cy = cy - 1 end
    return cx, cy, lx, ly
end

return Cave