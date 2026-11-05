-- Popup At Cursor
-- Copyright (c) 2026 Sky Schulz
-- SPDX-License-Identifier: MIT
-- See LICENSE for the full terms.

-- Proof of concept: scrolling FPS + latency graph for the last 120 seconds.
-- FPS is drawn as bars from the bottom; latency as a thin line on top.
-- Two lines of text under the graph show current FPS and latency, plus
-- min/avg/max for the visible period.

local _, ns = ...

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

-- The plot clips the scrolling strip; the text below sits outside the clip.
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

-- All columns live on one strip, one column wider than the graph. Each frame
-- only the strip moves; columns are restyled when a new sample arrives.
local strip = CreateFrame("Frame", nil, plot)
strip:SetSize(WIDTH + COL_W, HEIGHT)
strip:SetPoint("TOPLEFT")

local bars, lines = {}, {}
for i = 1, SAMPLES + 1 do
    local x = (i - 1) * COL_W
    local bar = strip:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(1, 1, 1)
    bar:SetWidth(COL_W)
    bar:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x, 0)
    NoSnap(bar)
    bar:Hide()
    bars[i] = bar

    local line = strip:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(1, 1, 1)
    line:SetSize(COL_W, LINE_H)
    NoSnap(line)
    line:Hide()
    lines[i] = line
end

-- Oldest sample first; the newest sits in the extra column at the right edge.
local fpsHist, latHist = {}, {}

local function Colored(value, colorFn)
    if not value then return "|cff808080--|r" end
    local c = colorFn(value)
    return string.format("|cff%02x%02x%02x%d|r",
        math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255),
        math.floor(value + 0.5))
end

-- min/avg/max over the samples currently on screen (the newest SAMPLES),
-- skipping samples with no data (false). Returns nil if there are none.
local function Summarize(hist)
    local n = #hist
    local lo, hi, sum, count = math.huge, -math.huge, 0, 0
    for k = math.max(1, n - SAMPLES + 1), n do
        local v = hist[k]
        if v then
            if v < lo then lo = v end
            if v > hi then hi = v end
            sum, count = sum + v, count + 1
        end
    end
    if count == 0 then return nil end
    return lo, sum / count, hi
end

local function StatsLine(fontString, label, hist, colorFn)
    if #hist == 0 then
        fontString:SetText("")
        return
    end
    local lo, avg, hi = Summarize(hist)
    fontString:SetText(string.format("%s  cur %s  min %s  avg %s  max %s", label,
        Colored(hist[#hist], colorFn), Colored(lo, colorFn),
        Colored(avg, colorFn), Colored(hi, colorFn)))
end

local function UpdateStats()
    StatsLine(fpsText, "FPS", fpsHist, FpsColor)
    StatsLine(latText, "MS ", latHist, LatencyColor)
end

local function Render()
    local first = SAMPLES + 2 - #fpsHist
    for i = 1, SAMPLES + 1 do
        local k = i - first + 1
        local fps, lat = fpsHist[k], latHist[k]
        local bar, line = bars[i], lines[i]
        if fps then
            local c = FpsColor(fps)
            bar:SetVertexColor(c[1], c[2], c[3], 0.55)
            bar:SetHeight(math.max(1, math.min(fps / FPS_MAX, 1) * HEIGHT))
            bar:Show()

            if lat then
                c = LatencyColor(lat)
                local y = math.min(lat / LAT_MAX, 1) * (HEIGHT - LINE_H)
                line:SetVertexColor(c[1], c[2], c[3], 1)
                line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (i - 1) * COL_W, y)
                line:Show()
            else
                line:Hide()
            end
        else
            bar:Hide()
            line:Hide()
        end
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
        fpsHist[#fpsHist + 1] = fps
        latHist[#latHist + 1] = Latency()
        if #fpsHist > SAMPLES + 1 then
            table.remove(fpsHist, 1)
            table.remove(latHist, 1)
        end
        Render()
        UpdateStats()
    end
    strip:SetPoint("TOPLEFT", graph, "TOPLEFT", -(elapsedInSample / INTERVAL) * COL_W, 0)
end)

---------------------------------------------------------------------------
-- Position: Shift-drag anywhere, or /pac graph tl|tc|tr|bl|bc|br
---------------------------------------------------------------------------

local PRESETS = {
    tl = { "TOPLEFT",     MARGIN,  -MARGIN, "top left" },
    tc = { "TOP",         0,       -MARGIN, "top center" },
    tr = { "TOPRIGHT",    -MARGIN, -MARGIN, "top right" },
    bl = { "BOTTOMLEFT",  MARGIN,  MARGIN,  "bottom left" },
    bc = { "BOTTOM",      0,       MARGIN,  "bottom center" },
    br = { "BOTTOMRIGHT", -MARGIN, MARGIN,  "bottom right" },
}

-- Saved as db.graphPos = { point, relativePoint, x, y } against UIParent.
local function ApplyPosition(pos)
    graph:ClearAllPoints()
    graph:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
end

local function SavePosition()
    local point, _, relativePoint, x, y = graph:GetPoint(1)
    ns.db.graphPos = { point, relativePoint, x, y }
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
    for k = #fpsHist, 1, -1 do
        fpsHist[k], latHist[k] = nil, nil
    end
    Render()
    UpdateStats()
end)

function ns.SetGraphShown(shown)
    ns.db.graph = shown
    graph:SetShown(shown)
end

function ns.ToggleGraph()
    ns.SetGraphShown(not graph:IsShown())
    return ns.db.graph
end

-- Move to a preset ("tl", "tc", ...) and show the graph. Returns the
-- preset's name, or nil if `where` isn't one.
function ns.PlaceGraph(where)
    local p = PRESETS[where]
    if not p then return nil end
    ns.db.graphPos = { p[1], p[1], p[2], p[3] }
    ApplyPosition(ns.db.graphPos)
    ns.SetGraphShown(true)
    return p[4]
end

function ns.OnLoaded(db)
    if db.graph == nil then db.graph = true end -- POC: on by default
    local pos = db.graphPos
    if type(pos) == "table" and type(pos[1]) == "string" and type(pos[2]) == "string"
            and type(pos[3]) == "number" and type(pos[4]) == "number" then
        ApplyPosition(pos)
    else
        db.graphPos = nil
    end
    graph:SetShown(db.graph)
end
