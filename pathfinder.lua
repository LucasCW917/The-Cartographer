-- pathfinder.lua
local Pathfinder = {}

-- Min-heap
local function heapPush(heap, node)
    table.insert(heap, node)
    local i = #heap
    while i > 1 do
        local parent = math.floor(i / 2)
        if heap[parent].f > heap[i].f then
            heap[parent], heap[i] = heap[i], heap[parent]
            i = parent
        else break end
    end
end

local function heapPop(heap)
    local top  = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local i = 1
        while true do
            local l, r, s = i*2, i*2+1, i
            if l <= #heap and heap[l].f < heap[s].f then s = l end
            if r <= #heap and heap[r].f < heap[s].f then s = r end
            if s == i then break end
            heap[i], heap[s] = heap[s], heap[i]
            i = s
        end
    end
    return top
end

local function heuristic(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function key(x, y) return x .. "," .. y end

local function astar(cave, startX, startY, goalX, goalY, maxNodes, costFn)
    maxNodes = maxNodes or 4000

    local open     = {}
    local closed   = {}
    local cameFrom = {}
    local gScore   = {}

    local sk = key(startX, startY)
    gScore[sk] = 0
    heapPush(open, { x=startX, y=startY, f=heuristic(startX, startY, goalX, goalY) })

    local visited = 0

    while #open > 0 do
        local current = heapPop(open)
        local ck = key(current.x, current.y)

        if closed[ck] then goto continue end
        closed[ck] = true
        visited    = visited + 1

        if current.x == goalX and current.y == goalY then
            local path = {}
            local k = ck
            while cameFrom[k] do
                local node = cameFrom[k]
                table.insert(path, 1, { x=node.x, y=node.y })
                k = key(node.x, node.y)
            end
            table.insert(path, { x=goalX, y=goalY })
            return path
        end

        if visited > maxNodes then return nil end

        local neighbors = {
            { x=current.x+1, y=current.y },
            { x=current.x-1, y=current.y },
            { x=current.x,   y=current.y+1 },
            { x=current.x,   y=current.y-1 },
        }

        for _, nb in ipairs(neighbors) do
            local nk   = key(nb.x, nb.y)
            local cost = costFn(cave, nb.x, nb.y)
            if not closed[nk] and cost < math.huge then
                local tentative = (gScore[ck] or math.huge) + cost
                if tentative < (gScore[nk] or math.huge) then
                    gScore[nk]    = tentative
                    cameFrom[nk]  = { x=current.x, y=current.y }
                    heapPush(open, {
                        x = nb.x,
                        y = nb.y,
                        f = tentative + heuristic(nb.x, nb.y, goalX, goalY)
                    })
                end
            end
        end

        ::continue::
    end

    return nil
end

-- Standard pathfinding: floor only
local function floorCost(cave, x, y)
    if cave:get(x, y) == cave.FLOOR then return 1 end
    return math.huge  -- impassable
end

-- Diggable pathfinding: floor = 1, solid = 20 (expensive but passable)
local function diggableCost(cave, x, y)
    local t = cave:get(x, y)
    if t == cave.FLOOR  then return 1  end
    if t == cave.SOLID  then return 20 end
    return math.huge
end

function Pathfinder.find(cave, startX, startY, goalX, goalY, maxNodes)
    return astar(cave, startX, startY, goalX, goalY, maxNodes, floorCost)
end

function Pathfinder.findDiggable(cave, startX, startY, goalX, goalY, maxNodes)
    -- For infinite caves, cap nodes higher since the cave may be sparse
    maxNodes = maxNodes or 8000
    return astar(cave, startX, startY, goalX, goalY, maxNodes, diggableCost)
end

return Pathfinder