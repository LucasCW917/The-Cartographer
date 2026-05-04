-- pathfinder.lua
local Pathfinder = {}

-- Min-heap implementation
local function heapPush(heap, node)
    table.insert(heap, node)
    local i = #heap
    while i > 1 do
        local parent = math.floor(i / 2)
        if heap[parent].f > heap[i].f then
            heap[parent], heap[i] = heap[i], heap[parent]
            i = parent
        else
            break
        end
    end
end

local function heapPop(heap)
    local top = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local i = 1
        while true do
            local left  = i * 2
            local right = i * 2 + 1
            local smallest = i
            if left  <= #heap and heap[left].f  < heap[smallest].f then smallest = left  end
            if right <= #heap and heap[right].f < heap[smallest].f then smallest = right end
            if smallest == i then break end
            heap[i], heap[smallest] = heap[smallest], heap[i]
            i = smallest
        end
    end
    return top
end

local function heuristic(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function key(x, y) return x .. "," .. y end

function Pathfinder.find(cave, startX, startY, goalX, goalY, maxNodes)
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
        visited = visited + 1

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
            local nk = key(nb.x, nb.y)
            if not closed[nk] and cave:get(nb.x, nb.y) == cave.FLOOR then
                local tentative = (gScore[ck] or math.huge) + 1
                if tentative < (gScore[nk] or math.huge) then
                    gScore[nk]   = tentative
                    cameFrom[nk] = { x=current.x, y=current.y }
                    heapPush(open, { x=nb.x, y=nb.y, f=tentative + heuristic(nb.x, nb.y, goalX, goalY) })
                end
            end
        end

        ::continue::
    end

    return nil
end

return Pathfinder