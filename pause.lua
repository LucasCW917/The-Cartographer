-- pause.lua
local Saves = require("saves")

local Pause = {}
Pause.__index = Pause

local TABS = { "resume", "save", "load", "settings", "abandon" }

function Pause.new(W, H, font, smallFont)
    local self      = setmetatable({}, Pause)
    self.W          = W
    self.H          = H
    self.font       = font
    self.smallFont  = smallFont
    self.visible    = false
    self.tab        = "resume"

    -- Save name input
    self.saveInput  = { value="", active=false, placeholder="Save name..." }

    -- Load screen
    self.saves      = {}
    self.loadScroll = 0
    self.selectedSave = nil

    -- Feedback message
    self.message    = nil
    self.messageTimer = 0

    -- Panel dimensions
    self.pw = 460
    self.ph = 420
    self.px = W/2 - 230
    self.py = H/2 - 210

    self.buttons = {}
    return self
end

function Pause:open()
    self.visible  = true
    self.tab      = "resume"
    self.saves    = Saves.list()
    self.saveInput.value = ""
end

function Pause:close()
    self.visible = false
end

function Pause:setMessage(msg)
    self.message      = msg
    self.messageTimer = 3.0
end

function Pause:update(dt)
    if self.messageTimer > 0 then
        self.messageTimer = self.messageTimer - dt
        if self.messageTimer <= 0 then self.message = nil end
    end
end

function Pause:_isHovered(btn)
    local mx, my = love.mouse.getPosition()
    return mx > btn.x and mx < btn.x+btn.w and my > btn.y and my < btn.y+btn.h
end

function Pause:_drawBtn(x, y, w, h, label, active, danger)
    local btn = { x=x, y=y, w=w, h=h }
    local hovered = self:_isHovered(btn)
    local col = danger  and {0.70,0.25,0.25} or
                active  and {0.88,0.82,0.68,0.20} or
                hovered and {0.88,0.82,0.68,0.09} or
                            {0,0,0,0}
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(
        danger  and {0.90,0.40,0.40,0.8} or
        hovered and {0.88,0.82,0.68,0.6} or
                    {0.45,0.40,0.32,0.5}
    )
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setFont(self.font)
    love.graphics.setColor(
        danger  and {1.0,0.65,0.65} or
        hovered and {0.95,0.90,0.75} or
                    {0.65,0.60,0.48}
    )
    local tw = self.font:getWidth(label)
    local fh = self.font:getHeight()
    love.graphics.print(label, x+w/2-tw/2, y+h/2-fh/2)
    return hovered
end

function Pause:draw()
    if not self.visible then return end

    local px, py, pw, ph = self.px, self.py, self.pw, self.ph
    local cx = px + 16
    local fh = self.font:getHeight()

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, self.W, self.H)

    -- Panel
    love.graphics.setColor(0.07, 0.06, 0.04, 0.98)
    love.graphics.rectangle("fill", px, py, pw, ph)
    love.graphics.setColor(0.55, 0.48, 0.36, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px, py, pw, ph)

    -- Tab bar
    local tabW = pw / #TABS
    local tabLabels = {
        resume   = "Resume",
        save     = "Save",
        load     = "Load",
        settings = "Settings",
        abandon  = "Abandon",
    }
    self.buttons.tabs = {}
    for i, tabId in ipairs(TABS) do
        local tx  = px + (i-1)*tabW
        local ty  = py
        local active = self.tab == tabId
        local danger = tabId == "abandon"
        local hovered = self:_drawBtn(tx, ty, tabW, 32, tabLabels[tabId], active, danger and not active)
        self.buttons.tabs[i] = { x=tx, y=ty, w=tabW, h=32, id=tabId, hovered=hovered }
    end

    -- Divider
    love.graphics.setColor(0.45, 0.40, 0.30, 0.5)
    love.graphics.line(px, py+32, px+pw, py+32)

    local cy = py + 48

    -- ── Resume tab ────────────────────────────────────────────────────
    if self.tab == "resume" then
        love.graphics.setFont(self.font)
        love.graphics.setColor(0.70, 0.62, 0.46)
        local title = "Paused"
        love.graphics.print(title, px+pw/2 - self.font:getWidth(title)/2, cy)
        cy = cy + fh + 20

        -- Controls reference
        local controls = {
            { "WASD",        "Pan camera"              },
            { "Scroll",      "Zoom in / out"           },
            { "Left-click",  "Select probe"            },
            { "Shift+click", "Add to selection"        },
            { "Right-click", "Dispatch selected probes"},
            { "Set Target",  "Then click map to move"  },
            { "ESC",         "Pause / unpause"         },
        }
        for _, row in ipairs(controls) do
            love.graphics.setFont(self.font)
            love.graphics.setColor(0.75, 0.70, 0.55)
            love.graphics.print(row[1], cx, cy)
            love.graphics.setFont(self.smallFont)
            love.graphics.setColor(0.50, 0.46, 0.36)
            love.graphics.print(row[2], cx + 130, cy + 3)
            cy = cy + fh + 4
        end

        cy = cy + 10
        self.buttons.resume = { x=cx, y=cy, w=pw-32, h=34 }
        self:_drawBtn(cx, cy, pw-32, 34, "Continue Expedition")

    -- ── Save tab ──────────────────────────────────────────────────────
    elseif self.tab == "save" then
        love.graphics.setFont(self.font)
        love.graphics.setColor(0.70, 0.62, 0.46)
        love.graphics.print("Save Expedition", cx, cy)
        cy = cy + fh + 12

        -- Name input
        local inp = self.saveInput
        love.graphics.setColor(0.55, 0.50, 0.40)
        love.graphics.print("Save name", cx, cy)
        cy = cy + fh + 4

        love.graphics.setColor(0.05, 0.04, 0.03, 0.9)
        love.graphics.rectangle("fill", cx, cy, pw-32, 34)
        love.graphics.setColor(inp.active and {0.88,0.82,0.68,0.6} or {0.45,0.40,0.32,0.5})
        love.graphics.rectangle("line", cx, cy, pw-32, 34)
        local display = #inp.value > 0 and inp.value or inp.placeholder
        love.graphics.setColor(#inp.value > 0 and {0.88,0.82,0.68} or {0.35,0.32,0.26})
        love.graphics.setFont(self.font)
        love.graphics.print(display, cx+10, cy+8)
        if inp.active and (love.timer.getTime() % 1) < 0.5 then
            local curX = cx + 10 + self.font:getWidth(inp.value)
            love.graphics.setColor(0.88, 0.82, 0.68, 0.8)
            love.graphics.line(curX, cy+6, curX, cy+26)
        end
        self.buttons.saveInput = { x=cx, y=cy, w=pw-32, h=34 }
        cy = cy + 34 + 10

        local canSave = #inp.value > 0
        love.graphics.setColor(not canSave and {0.30,0.28,0.22} or {1,1,1,0})
        self.buttons.doSave = { x=cx, y=cy, w=pw-32, h=34 }
        self:_drawBtn(cx, cy, pw-32, 34, "Save")
        cy = cy + 34 + 16

        -- Existing saves list
        love.graphics.setColor(0.45, 0.40, 0.30, 0.5)
        love.graphics.line(cx, cy, cx+pw-32, cy)
        cy = cy + 8
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.50, 0.46, 0.36)
        love.graphics.print("Existing saves  (click to overwrite name)", cx, cy)
        cy = cy + self.smallFont:getHeight() + 6

        self.buttons.saveRows = {}
        local listH = ph - (cy - py) - 12
        love.graphics.setScissor(px, cy, pw, listH)
        local ry = cy - self.loadScroll
        for i, sv in ipairs(self.saves) do
            if ry + 36 > cy and ry < cy + listH then
                local hov = self:_isHovered({ x=cx, y=ry, w=pw-32, h=34 })
                love.graphics.setColor(hov and {0.88,0.82,0.68,0.07} or {0,0,0,0})
                love.graphics.rectangle("fill", cx, ry, pw-32, 34)
                love.graphics.setFont(self.font)
                love.graphics.setColor(0.70, 0.65, 0.50)
                love.graphics.print(sv.filename:gsub("%.lua$",""), cx+6, ry+4)
                love.graphics.setFont(self.smallFont)
                love.graphics.setColor(0.45, 0.42, 0.34)
                love.graphics.print(
                    sv.playerName .. "  ·  " .. sv.difficulty .. "  ·  " .. Saves.timestampToString(sv.timestamp),
                    cx+6, ry+4+fh+1
                )
                love.graphics.setColor(0.30,0.27,0.20,0.4)
                love.graphics.line(cx, ry+34, cx+pw-32, ry+34)
                self.buttons.saveRows[i] = { x=cx, y=ry, w=pw-32, h=34, filename=sv.filename:gsub("%.lua$","") }
            end
            ry = ry + 36
        end
        love.graphics.setScissor()

    -- ── Load tab ──────────────────────────────────────────────────────
    elseif self.tab == "load" then
        love.graphics.setFont(self.font)
        love.graphics.setColor(0.70, 0.62, 0.46)
        love.graphics.print("Load Expedition", cx, cy)
        cy = cy + fh + 12

        self.buttons.loadRows = {}
        self.buttons.deleteRows = {}
        local listH = ph - (cy - py) - 12
        love.graphics.setScissor(px, cy, pw, listH)
        local ry = cy - self.loadScroll

        if #self.saves == 0 then
            love.graphics.setFont(self.smallFont)
            love.graphics.setColor(0.40, 0.37, 0.30)
            love.graphics.print("No saves found.", cx, ry)
        end

        for i, sv in ipairs(self.saves) do
            if ry + 44 > cy and ry < cy + listH then
                local rowW = pw - 32
                local delW = 28
                local hov  = self:_isHovered({ x=cx, y=ry, w=rowW-delW-4, h=42 })
                love.graphics.setColor(hov and {0.88,0.82,0.68,0.07} or {0,0,0,0})
                love.graphics.rectangle("fill", cx, ry, rowW-delW-4, 42)

                love.graphics.setFont(self.font)
                love.graphics.setColor(0.75, 0.70, 0.55)
                love.graphics.print(sv.filename:gsub("%.lua$",""), cx+6, ry+4)
                love.graphics.setFont(self.smallFont)
                love.graphics.setColor(0.48, 0.44, 0.35)
                love.graphics.print(
                    sv.playerName .. "  ·  " .. sv.difficulty .. "  ·  " .. Saves.timestampToString(sv.timestamp),
                    cx+6, ry+6+fh
                )

                -- Delete button
                self:_drawBtn(cx+rowW-delW, ry+7, delW, 28, "✕", false, true)

                love.graphics.setColor(0.28,0.25,0.19,0.4)
                love.graphics.line(cx, ry+43, cx+rowW, ry+43)

                self.buttons.loadRows[i]   = { x=cx, y=ry, w=rowW-delW-4, h=42, data=sv.data }
                self.buttons.deleteRows[i] = { x=cx+rowW-delW, y=ry+7, w=delW, h=28, filename=sv.filename }
            end
            ry = ry + 45
        end
        love.graphics.setScissor()

    -- ── Settings tab ──────────────────────────────────────────────────
    elseif self.tab == "settings" then
        love.graphics.setFont(self.font)
        love.graphics.setColor(0.70, 0.62, 0.46)
        love.graphics.print("Settings", cx, cy)
        cy = cy + fh + 16
        love.graphics.setColor(0.45, 0.42, 0.34)
        love.graphics.setFont(self.smallFont)
        love.graphics.print("No settings available yet.", cx, cy)

    -- ── Abandon tab ───────────────────────────────────────────────────
    elseif self.tab == "abandon" then
        love.graphics.setFont(self.font)
        love.graphics.setColor(0.85, 0.35, 0.35)
        local title = "Abandon Expedition"
        love.graphics.print(title, px+pw/2-self.font:getWidth(title)/2, cy)
        cy = cy + fh + 12

        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.55, 0.50, 0.40)
        local lines = {
            "You will lose all unsaved progress.",
            "Your probes will be left in the dark.",
            "The caves will forget you were ever here.",
        }
        for _, line in ipairs(lines) do
            love.graphics.print(line, px+pw/2-self.smallFont:getWidth(line)/2, cy)
            cy = cy + self.smallFont:getHeight() + 4
        end
        cy = cy + 16

        self.buttons.abandon = { x=cx, y=cy, w=pw-32, h=34 }
        self:_drawBtn(cx, cy, pw-32, 34, "Abandon — Return to Menu", false, true)
    end

    -- Feedback message
    if self.message then
        local alpha = math.min(1, self.messageTimer)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.70, 0.90, 0.60, alpha)
        local mw = self.smallFont:getWidth(self.message)
        love.graphics.print(self.message, px+pw/2-mw/2, py+ph-24)
    end

    love.graphics.setColor(1, 1, 1)
end

function Pause:mousepressed(mx, my, btn, onLoad, onAbandon, onSave, setup, depot, cave)
    if not self.visible then return false end
    if btn ~= 1 then return true end

    -- Tab bar
    if self.buttons.tabs then
        for _, tab in ipairs(self.buttons.tabs) do
            if mx > tab.x and mx < tab.x+tab.w and my > tab.y and my < tab.y+tab.h then
                self.tab = tab.id
                self.loadScroll = 0
                if self.tab == "load" or self.tab == "save" then
                    self.saves = Saves.list()
                end
                return true
            end
        end
    end

    -- Resume
    if self.tab == "resume" and self.buttons.resume then
        local b = self.buttons.resume
        if mx > b.x and mx < b.x+b.w and my > b.y and my < b.y+b.h then
            self:close()
            return true
        end
    end

    -- Save tab
    if self.tab == "save" then
        local si = self.buttons.saveInput
        if si and mx > si.x and mx < si.x+si.w and my > si.y and my < si.y+si.h then
            self.saveInput.active = true
            return true
        else
            self.saveInput.active = false
        end

        local ds = self.buttons.doSave
        if ds and mx > ds.x and mx < ds.x+ds.w and my > ds.y and my < ds.y+ds.h then
            if #self.saveInput.value > 0 then
                local data = Saves.serialise(setup, depot, cave)
                Saves.write(self.saveInput.value, data)
                if onSave then onSave() end
                self:setMessage("Saved: " .. self.saveInput.value)
                self.saves = Saves.list()
            end
            return true
        end

        if self.buttons.saveRows then
            for _, row in ipairs(self.buttons.saveRows) do
                if mx > row.x and mx < row.x+row.w and my > row.y and my < row.y+row.h then
                    self.saveInput.value = row.filename
                    return true
                end
            end
        end
    end

    -- Load tab
    if self.tab == "load" then
        if self.buttons.deleteRows then
            for _, row in ipairs(self.buttons.deleteRows) do
                if mx > row.x and mx < row.x+row.w and my > row.y and my < row.y+row.h then
                    Saves.delete(row.filename)
                    self.saves = Saves.list()
                    self:setMessage("Deleted.")
                    return true
                end
            end
        end
        if self.buttons.loadRows then
            for _, row in ipairs(self.buttons.loadRows) do
                if mx > row.x and mx < row.x+row.w and my > row.y and my < row.y+row.h then
                    if onLoad then onLoad(row.data) end
                    self:close()
                    return true
                end
            end
        end
    end

    -- Abandon tab
    if self.tab == "abandon" and self.buttons.abandon then
        local b = self.buttons.abandon
        if mx > b.x and mx < b.x+b.w and my > b.y and my < b.y+b.h then
            if onAbandon then onAbandon() end
            self:close()
            return true
        end
    end

    return true  -- swallow all clicks when open
end

function Pause:keypressed(key)
    if not self.visible then return false end

    if self.tab == "save" and self.saveInput.active then
        if key == "backspace" then
            self.saveInput.value = self.saveInput.value:sub(1, -2)
        end
        return true
    end

    if key == "escape" then
        self:close()
        return true
    end

    return true
end

function Pause:textinput(t)
    if not self.visible then return false end
    if self.tab == "save" and self.saveInput.active then
        -- Sanitise: only allow filename-safe chars
        if t:match("[%w%s%-_]") then
            self.saveInput.value = self.saveInput.value .. t
        end
    end
    return true
end

function Pause:wheelmoved(y)
    if not self.visible then return false end
    if self.tab == "load" or self.tab == "save" then
        self.loadScroll = math.max(0, self.loadScroll - y * 30)
    end
    return true
end

return Pause