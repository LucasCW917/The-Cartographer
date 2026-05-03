-- pathfinder.lua
local Pathfinder = {}

local function heuristic(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

local function key(x, y) return x .. "," .. y end

function Pathfinder.find(cave, startX, startY, goalX, goalY, maxNodes)
    maxNodes = maxNodes or 2000

    local open      = {}
    local closed    = {}
    local cameFrom  = {}
    local gScore    = {}
    local fScore    = {}

    local sk = key(startX, startY)
    gScore[sk] = 0
    fScore[sk] = heuristic(startX, startY, goalX, goalY)
    table.insert(open, { x=startX, y=startY, f=fScore[sk] })

    local visited = 0

    while #open > 0 do
        local lowestI, lowestF = 1, math.huge
        for i, node in ipairs(open) do
            if node.f < lowestF then
                lowestI, lowestF = i, node.f
            end
        end

        local current = open[lowestI]
        table.remove(open, lowestI)

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
                    gScore[nk]  = tentative
                    fScore[nk]  = tentative + heuristic(nb.x, nb.y, goalX, goalY)
                    cameFrom[nk] = { x=current.x, y=current.y }
                    table.insert(open, { x=nb.x, y=nb.y, f=fScore[nk] })
                end
            end
        end

        ::continue::
    end

    return nil
end

return Pathfinder