-- saves.lua
local Saves = {}

local SAVE_DIR = "saves/"

local function ensureDir()
    if not love.filesystem.getInfo(SAVE_DIR) then
        love.filesystem.createDirectory(SAVE_DIR)
    end
end

local function serialiseValue(v, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local t = type(v)
    if t == "number"  then return tostring(v)
    elseif t == "boolean" then return tostring(v)
    elseif t == "string"  then return string.format("%q", v)
    elseif t == "table"   then
        local parts = {}
        local isArray = (#v > 0)
        if isArray then
            for _, val in ipairs(v) do
                table.insert(parts, pad .. "  " .. serialiseValue(val, indent+1))
            end
        else
            for key, val in pairs(v) do
                local keyStr = type(key) == "string" and key or string.format("[%s]", tostring(key))
                table.insert(parts, pad .. "  " .. keyStr .. " = " .. serialiseValue(val, indent+1))
            end
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
    end
    return "nil"
end

local function writeTable(tbl)
    local parts = {}
    for k, v in pairs(tbl) do
        table.insert(parts, string.format("  %s = %s", k, serialiseValue(v, 1)))
    end
    return "return {\n" .. table.concat(parts, ",\n") .. "\n}\n"
end

function Saves.serialise(setup, depot, cave)
    local probes = {}
    for _, p in ipairs(depot.probes) do
        if p.alive then
            table.insert(probes, {
                id     = p.id,
                type   = p.type,
                weapon = p.weapon,
                roe    = p.roe,
                x      = math.floor(p.x),
                y      = math.floor(p.y),
                hp     = p.hp,
                status = p.status,
                cargo  = p.cargo,
            })
        end
    end

    return {
        version    = 1,
        timestamp  = os.time(),
        playerName = setup.name.value,
        difficulty = setup.difficulty,
        seed       = cave.seed,
        infinite   = cave.infinite or false,
        caveW      = (cave.width  ~= math.huge) and cave.width  or 0,
        caveH      = (cave.height ~= math.huge) and cave.height or 0,
        depotX     = depot.x,
        depotY     = depot.y,
        resources  = {
            metal  = depot.resources.metal,
            energy = depot.resources.energy,
            rare   = depot.resources.rare,
        },
        nextId     = depot.nextId,
        probes     = probes,
    }
end

function Saves.list()
    ensureDir()
    local files = love.filesystem.getDirectoryItems(SAVE_DIR)
    local saves = {}
    for _, f in ipairs(files) do
        if f:match("%.lua$") then
            local ok, data = pcall(function()
                return love.filesystem.load(SAVE_DIR .. f)()
            end)
            if ok and data then
                table.insert(saves, {
                    filename   = f,
                    playerName = data.playerName or "Unknown",
                    difficulty = data.difficulty or "?",
                    timestamp  = data.timestamp  or 0,
                    data       = data,
                })
            end
        end
    end
    table.sort(saves, function(a, b) return a.timestamp > b.timestamp end)
    return saves
end

function Saves.write(name, data)
    ensureDir()
    local filename = SAVE_DIR .. name .. ".lua"
    local str = writeTable(data)
    return love.filesystem.write(filename, str)
end

function Saves.delete(filename)
    love.filesystem.remove(SAVE_DIR .. filename)
end

function Saves.timestampToString(ts)
    return os.date("%Y-%m-%d  %H:%M", ts)
end

return Saves