-- Popup At Cursor
-- Copyright (c) 2026 Sky Schulz
-- SPDX-License-Identifier: MIT
-- See LICENSE for the full terms.

-- Proof of concept: scrolling FPS + latency graph for the last 120 seconds.
-- FPS is drawn as bars from the bottom; latency as a thin line on top.
-- Two lines of text under the graph show current FPS and latency, plus
-- min/avg/max for the visible period.

local _, ns = ...
local db -- PopupAtCursorDB, handed over by ns.OnLoaded at ADDON_LOADED

local WIDTH, HEIGHT = 240, 60   -- pixels
local WINDOW = 120              -- seconds shown
local INTERVAL = 0.5            -- seconds per sample
local SAMPLES = WINDOW / INTERVAL
local COL_W = WIDTH / SAMPLES
local FPS_MAX = 120             -- bar height tops out here
local LAT_MAX = 150             -- line height tops out here (ms)
local LINE_H = 2
local TEXT_H = 30               -- room for the two stats lines under the plot
local MARGIN = 8                -- gap from the screen edge for /pac graph presets

local GREEN  = { 0.15, 0.90, 0.15 }
local YELLOW = { 1.00, 0.85, 0.00 }
local RED    = { 1.00, 0.20, 0.20 }

local function FpsColor(fps)
    if fps >= 60 then return GREEN elseif fps >= 30 then return YELLOW end
    return RED
end

local function LatencyColor(ms)
    if ms < 20 then return GREEN elseif ms <= 60 then return YELLOW end
    return RED
end

-- false until the game has reported a latency (0 just after login/reload),
-- so "no data" isn't drawn or counted as a perfect 0 ms.
local function Latency()
    local _, _, home, world = GetNetStats()
    local ms = math.max(home or 0, world or 0)
    return ms > 0 and ms or false
end

local function NoSnap(region)
    if region.SetSnapToPixelGrid then
        region:SetSnapToPixelGrid(false)
        region:SetTexelSnappingBias(0)
    end
end

-- The frame covers the plot and the text under it, so clamping and the
-- bottom-edge presets keep the text on screen.
local graph = CreateFrame("Frame", "PopupAtCursorStatsGraph", UIParent)
graph:SetSize(WIDTH, HEIGHT + TEXT_H)
graph:SetPoint("TOPLEFT", UIParent, "TOPLEFT", MARGIN, -MARGIN)
graph:SetAlpha(0.75)
graph:SetFrameStrata("LOW")
graph:SetMovable(true)
graph:SetClampedToScreen(true)
graph:RegisterForDrag("LeftButton")
graph:EnableMouse(false) -- click-through, except while Shift is held (see below)
graph:Hide()

-- The plot clips the scrolling strips; the text below sits outside the clip.
local plot = CreateFrame("Frame", nil, graph)
plot:SetPoint("TOPLEFT")
plot:SetSize(WIDTH, HEIGHT)
plot:SetClipsChildren(true)

local fpsText = graph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
fpsText:SetPoint("TOPLEFT", plot, "BOTTOMLEFT", 0, -2)
fpsText:SetJustifyH("LEFT")

local latText = graph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
latText:SetPoint("TOPLEFT", fpsText, "BOTTOMLEFT", 0, -2)
latText:SetJustifyH("LEFT")

-- Two strips, each one graph wide, leapfrog through the clipping plot like a
-- viewport over a strip twice the graph's width. Sample k is drawn once, into
-- column c = (k-1) % SAMPLES + 1 of strip A or B in turn, and never restyled.
-- Each frame only the current strip moves; the other is anchored to its left
-- edge and follows. When a strip starts refilling, the two swap anchors.
-- The refilling strip's old columns sit right of the newest sample, so the plot
-- clips them until they're overwritten.
local strips = {}
for s = 1, 2 do
    local strip = CreateFrame("Frame", nil, plot)
    strip:SetSize(WIDTH, HEIGHT)
    strip.bars, strip.lines = {}, {}
    for c = 1, SAMPLES do
        local bar = strip:CreateTexture(nil, "ARTWORK")
        bar:SetColorTexture(1, 1, 1)
        bar:SetWidth(COL_W)
        bar:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (c - 1) * COL_W, 0)
        NoSnap(bar)
        bar:Hide()
        strip.bars[c] = bar

        local line = strip:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1)
        line:SetSize(COL_W, LINE_H)
        NoSnap(line)
        line:Hide()
        strip.lines[c] = line
    end
    strips[s] = strip
end

-- Ring buffers of the last SAMPLES samples; sample k sits at slot (k-1) % SAMPLES + 1,
-- the same index as its column. Used only for the stats text.
local fpsRing, latRing = {}, {}
local count = 0     -- samples taken since the graph was last shown
local current       -- the strip holding the newest sample

local function Slot(k) return (k - 1) % SAMPLES + 1 end
local function StripFor(k) return strips[math.floor((k - 1) / SAMPLES) % 2 + 1] end

-- Put `strip` under the plot's control and hang the other strip off its left edge.
-- (Clear first: the two strips anchor to each other, and a cycle is an error.)
local function MakeCurrent(strip)
    local other = strip == strips[1] and strips[2] or strips[1]
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", plot, "TOPLEFT", WIDTH, 0)
    other:ClearAllPoints()
    other:SetPoint("TOPRIGHT", strip, "TOPLEFT", 0, 0)
    current = strip
end

local function Reset()
    for s = 1, 2 do
        for c = 1, SAMPLES do
            strips[s].bars[c]:Hide()
            strips[s].lines[c]:Hide()
        end
    end
    for i = 1, SAMPLES do fpsRing[i], latRing[i] = nil, nil end
    count = 0
    MakeCurrent(strips[1])
end

local function Colored(value, colorFn)
    if not value then return "|cff808080--|r" end
    local c = colorFn(value)
    return string.format("|cff%02x%02x%02x%d|r",
        math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255),
        math.floor(value + 0.5))
end

-- min/avg/max over the samples on screen (the ring), skipping samples with no
-- data (false). Returns nil if there are none.
local function Summarize(ring)
    local lo, hi, sum, n = math.huge, -math.huge, 0, 0
    for i = 1, math.min(count, SAMPLES) do
        local v = ring[i]
        if v then
            if v < lo then lo = v end
            if v > hi then hi = v end
            sum, n = sum + v, n + 1
        end
    end
    if n == 0 then return nil end
    return lo, sum / n, hi
end

local function StatsLine(fontString, label, ring, colorFn)
    if count == 0 then
        fontString:SetText("")
        return
    end
    local lo, avg, hi = Summarize(ring)
    fontString:SetText(string.format("%s  cur %s  min %s  avg %s  max %s", label,
        Colored(ring[Slot(count)], colorFn), Colored(lo, colorFn),
        Colored(avg, colorFn), Colored(hi, colorFn)))
end

local function UpdateStats()
    StatsLine(fpsText, "FPS", fpsRing, FpsColor)
    StatsLine(latText, "MS ", latRing, LatencyColor)
end

-- Record sample k = count + 1 and draw its column: one bar and one dash.
local function AddSample(fps, lat)
    count = count + 1
    local c, strip = Slot(count), StripFor(count)
    fpsRing[c], latRing[c] = fps, lat
    if c == 1 and strip ~= current then MakeCurrent(strip) end

    local bar, line = strip.bars[c], strip.lines[c]
    local col = FpsColor(fps)
    bar:SetVertexColor(col[1], col[2], col[3], 0.55)
    bar:SetHeight(math.max(1, math.min(fps / FPS_MAX, 1) * HEIGHT))
    bar:Show()
    if lat then
        col = LatencyColor(lat)
        line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (c - 1) * COL_W,
            math.min(lat / LAT_MAX, 1) * (HEIGHT - LINE_H))
        line:SetVertexColor(col[1], col[2], col[3], 1)
        line:Show()
    else
        line:Hide()
    end
end

local elapsedInSample, frames = 0, 0
graph:SetScript("OnUpdate", function(_, elapsed)
    elapsedInSample = elapsedInSample + elapsed
    frames = frames + 1
    if elapsedInSample >= INTERVAL then
        local over = elapsedInSample - INTERVAL
        local fps
        if over < INTERVAL then
            -- The last frame straddles the boundary: credit the part past it to
            -- the next sample, so the scroll stays smooth and FPS stays exact.
            local carry = over / elapsed
            fps = (frames - carry) / INTERVAL
            frames, elapsedInSample = carry, over
        else
            -- A long hitch (loading screen, freeze): one low sample for the
            -- whole stretch, then start fresh instead of charging the leftover
            -- to the next frame.
            fps = frames / elapsedInSample
            frames, elapsedInSample = 0, 0
        end
        AddSample(fps, Latency())
        UpdateStats()
    end
    if count > 0 then
        -- The newest column slides in from the right edge over one interval.
        local x = WIDTH - (elapsedInSample / INTERVAL + Slot(count) - 1) * COL_W
        current:SetPoint("TOPLEFT", plot, "TOPLEFT", x, 0)
    end
end)

---------------------------------------------------------------------------
-- Position: Shift-drag anywhere, or /pac graph tl|tc|tr|ml|mc|mr|bl|bc|br
---------------------------------------------------------------------------

local PRESETS = {
    tl = { "TOPLEFT",     MARGIN,  -MARGIN, "top left" },
    tc = { "TOP",         0,       -MARGIN, "top center" },
    tr = { "TOPRIGHT",    -MARGIN, -MARGIN, "top right" },
    ml = { "LEFT",        MARGIN,  0,       "middle left" },
    mc = { "CENTER",      0,       0,       "center" },
    mr = { "RIGHT",       -MARGIN, 0,       "middle right" },
    bl = { "BOTTOMLEFT",  MARGIN,  MARGIN,  "bottom left" },
    bc = { "BOTTOM",      0,       MARGIN,  "bottom center" },
    br = { "BOTTOMRIGHT", -MARGIN, MARGIN,  "bottom right" },
}

-- Preset names in screen order, "||"-separated: a lone "|" starts a chat
-- escape code (|t texture, |c color...), so chat needs "||" for a literal pipe.
ns.GRAPH_PRESETS = "tl||tc||tr||ml||mc||mr||bl||bc||br"

-- Saved as db.graphPos = { point, relativePoint, x, y } against UIParent.
local function ApplyPosition(pos)
    graph:ClearAllPoints()
    graph:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
end

local function SavePosition()
    local point, _, relativePoint, x, y = graph:GetPoint(1)
    db.graphPos = { point, relativePoint, x, y }
end

local dragging = false
local function StopDrag()
    if not dragging then return end
    dragging = false
    graph:StopMovingOrSizing()
    graph:SetUserPlaced(false) -- the addon saves the position, not WoW's layout cache
    SavePosition()
end

graph:SetScript("OnDragStart", function(self)
    dragging = true
    self:StartMoving()
end)
graph:SetScript("OnDragStop", StopDrag)

-- Take the mouse only while Shift is down, so the graph never blocks clicks.
local function UpdateMouse()
    local shift = IsShiftKeyDown()
    if not shift then StopDrag() end
    graph:EnableMouse(shift)
end
graph:RegisterEvent("MODIFIER_STATE_CHANGED")
graph:SetScript("OnEvent", UpdateMouse)

-- Nothing is sampled while hidden (by /pac graph, Alt-Z or a cinematic), so
-- start over rather than butting old samples up against new ones.
graph:SetScript("OnShow", function()
    UpdateMouse()
    elapsedInSample, frames = 0, 0
    Reset()
    UpdateStats()
end)

function ns.SetGraphShown(shown)
    db.graph = shown
    graph:SetShown(shown)
end

function ns.ToggleGraph()
    ns.SetGraphShown(not graph:IsShown())
    return db.graph
end

-- Move to a preset ("tl", "tc", ...) and show the graph. Returns the
-- preset's name, or nil if `where` isn't one.
function ns.PlaceGraph(where)
    local p = PRESETS[where]
    if not p then return nil end
    db.graphPos = { p[1], p[1], p[2], p[3] }
    ApplyPosition(db.graphPos)
    ns.SetGraphShown(true)
    return p[4]
end

function ns.OnLoaded(savedDB)
    db = savedDB
    if db.graph == nil then db.graph = false end -- off until the user turns it on
    local pos = db.graphPos
    if type(pos) == "table" and type(pos[1]) == "string" and type(pos[2]) == "string"
            and type(pos[3]) == "number" and type(pos[4]) == "number" then
        ApplyPosition(pos)
    else
        db.graphPos = nil
    end
    graph:SetShown(db.graph)
end
