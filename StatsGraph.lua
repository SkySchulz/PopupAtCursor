-- Popup At Cursor
-- Copyright (c) 2026 Sky Schulz
-- SPDX-License-Identifier: MIT
-- See LICENSE for the full terms.

-- Proof of concept: scrolling FPS + latency graph for the last 120 seconds.
-- FPS is drawn as bars from the bottom; latency as a thin line on top.
-- A line of text under the graph shows min/avg/max FPS for the visible period.

local _, ns = ...

local WIDTH, HEIGHT = 240, 60   -- pixels
local WINDOW = 120              -- seconds shown
local INTERVAL = 0.5            -- seconds per sample
local SAMPLES = WINDOW / INTERVAL
local COL_W = WIDTH / SAMPLES
local FPS_MAX = 120             -- bar height tops out here
local LAT_MAX = 150             -- line height tops out here (ms)
local LINE_H = 2

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

local function Latency()
    local _, _, home, world = GetNetStats()
    return math.max(home or 0, world or 0)
end

local function NoSnap(region)
    if region.SetSnapToPixelGrid then
        region:SetSnapToPixelGrid(false)
        region:SetTexelSnappingBias(0)
    end
end

local graph = CreateFrame("Frame", "PopupAtCursorStatsGraph", UIParent)
graph:SetSize(WIDTH, HEIGHT)
graph:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 8, -8)
graph:SetAlpha(0.75)
graph:SetFrameStrata("LOW")
graph:EnableMouse(false)
graph:Hide()

-- The plot clips the scrolling strip; the text below sits outside the clip.
local plot = CreateFrame("Frame", nil, graph)
plot:SetAllPoints()
plot:SetClipsChildren(true)

local stats = graph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
stats:SetPoint("TOPLEFT", graph, "BOTTOMLEFT", 0, -2)
stats:SetJustifyH("LEFT")

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

local function Colored(fps)
    local c = FpsColor(fps)
    return string.format("|cff%02x%02x%02x%d|r",
        math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255),
        math.floor(fps + 0.5))
end

-- min/avg/max over the samples currently on screen (the newest SAMPLES).
local function UpdateStats()
    local n = #fpsHist
    if n == 0 then
        stats:SetText("")
        return
    end
    local first = math.max(1, n - SAMPLES + 1)
    local lo, hi, sum = math.huge, 0, 0
    for k = first, n do
        local fps = fpsHist[k]
        if fps < lo then lo = fps end
        if fps > hi then hi = fps end
        sum = sum + fps
    end
    stats:SetText(string.format("FPS  min %s  avg %s  max %s",
        Colored(lo), Colored(sum / (n - first + 1)), Colored(hi)))
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

            c = LatencyColor(lat)
            local y = math.min(lat / LAT_MAX, 1) * (HEIGHT - LINE_H)
            line:SetVertexColor(c[1], c[2], c[3], 1)
            line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", (i - 1) * COL_W, y)
            line:Show()
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
        fpsHist[#fpsHist + 1] = frames / elapsedInSample
        latHist[#latHist + 1] = Latency()
        if #fpsHist > SAMPLES + 1 then
            table.remove(fpsHist, 1)
            table.remove(latHist, 1)
        end
        frames = 0
        -- keep the leftover so scrolling stays smooth; drop it after a long hitch
        elapsedInSample = math.min(elapsedInSample - INTERVAL, INTERVAL)
        Render()
        UpdateStats()
    end
    strip:SetPoint("TOPLEFT", graph, "TOPLEFT", -(elapsedInSample / INTERVAL) * COL_W, 0)
end)

graph:SetScript("OnShow", function()
    elapsedInSample, frames = 0, 0
    UpdateStats()
end)

function ns.ToggleGraph()
    local db = ns.db
    db.graph = not graph:IsShown()
    graph:SetShown(db.graph)
    return db.graph
end

function ns.OnLoaded(db)
    if db.graph == nil then db.graph = true end -- POC: on by default
    graph:SetShown(db.graph)
end
