-- Popup At Cursor
-- Copyright (c) 2026 Sky Schulz
-- SPDX-License-Identifier: MIT
-- See LICENSE for the full terms.

local addonName, ns = ...

-- Popups listed in the options panel even before you've seen them.
-- Names missing from this client's StaticPopupDialogs are hidden.
local COMMON = {
    "CAMP", "CONFIRM_LOOT_ROLL", "CONFIRM_SUMMON", "CONFIRM_SUMMON_SCENARIO",
    "CONFIRM_SUMMON_STARTING_AREA", "DEATH", "DELETE_GOOD_ITEM", "DELETE_ITEM",
    "DUEL_REQUESTED", "EQUIP_BIND", "INSTANCE_BOOT", "INSTANCE_LOCK", "LOOT_BIND",
    "PARTY_INVITE", "PARTY_INVITE_XREALM", "QUIT", "RESURRECT",
    "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER", "TRADE", "USE_BIND",
}

local PREFIX = "|cff33ff99PopupAtCursor:|r "
local db -- PopupAtCursorDB: { skip = {name=true}, seen = {name=text|true}, debug = bool, graph = bool }

-- Turn a popup's prompt into one plain line: drop color/texture codes,
-- replace format placeholders with "...", collapse whitespace.
local function CleanText(s)
    if type(s) ~= "string" then return nil end
    local ok, out = pcall(function()
        return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                 :gsub("|T.-|t", ""):gsub("|A.-|a", "")
                 :gsub("|H.-|h", ""):gsub("|h", "")
                 :gsub("|n", " "):gsub("%%[%d%.%$%-]*[sdfi]", "...")
                 :gsub("%s+", " "):match("^%s*(.-)%s*$"))
    end)
    if ok and out ~= "" then return out end
    return nil
end

local function PopupText(f)
    local fs = f.text or f.Text or _G[f:GetName() .. "Text"]
    return fs and fs.GetText and CleanText(fs:GetText())
end

local function MoveToCursor(f)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    f:SetClampedToScreen(true)
    f:ClearAllPoints()
    -- line the first button up under the cursor
    local btn = f.button1 or _G[f:GetName() .. "Button1"]
    local dx, dy = 0, 0
    if btn and btn:IsShown() then
        local fx, fy = f:GetCenter()
        local bx, by = btn:GetCenter()
        if fx and bx then dx, dy = bx - fx, by - fy end
    end
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s - dx, y / s - dy)
end

hooksecurefunc("StaticPopup_Show", function(which)
    if not which or not db then return end
    for i = 1, 4 do
        local f = _G["StaticPopup" .. i]
        if f and f:IsShown() and f.which == which then
            db.seen[which] = PopupText(f) or db.seen[which] or true
            if db.debug then print(PREFIX .. "popup = " .. which) end
            if not db.skip[which] then
                MoveToCursor(f)
            end
            return
        end
    end
end)

---------------------------------------------------------------------------
-- Options panel
---------------------------------------------------------------------------

local ROW_HEIGHT = 36
local panel = CreateFrame("Frame")
panel.name = "Popup At Cursor"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Popup At Cursor")

local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
help:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
help:SetJustifyH("LEFT")
help:SetText("Checked popups stay where Blizzard puts them. Popups you've seen are added to this list automatically.")

local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 78)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)

local function TemplateText(name)
    local d = StaticPopupDialogs[name]
    return d and CleanText(d.text)
end

local function Description(name)
    local seen = db.seen[name]
    return (type(seen) == "string" and seen) or TemplateText(name) or ""
end

local function ShowTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.key)
    local desc = Description(row.key)
    if desc ~= "" then GameTooltip:AddLine(desc, 1, 1, 1, true) end
    GameTooltip:Show()
end

local rows = {}
local function GetRow(i)
    if rows[i] then return rows[i] end
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    cb.label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cb.label:SetPoint("TOPLEFT", cb, "TOPRIGHT", 4, -2)
    cb.desc = cb:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    cb.desc:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", 0, -2)
    cb.desc:SetJustifyH("LEFT")
    cb.desc:SetWordWrap(false) -- long prompts get truncated with "..."
    cb:SetScript("OnClick", function(self)
        db.skip[self.key] = self:GetChecked() or nil
    end)
    cb:SetScript("OnEnter", ShowTooltip)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = cb
    return cb
end

local function Refresh()
    if not db then return end
    local names, have = {}, {}
    local function add(n)
        if not have[n] then have[n] = true; names[#names + 1] = n end
    end
    for _, n in ipairs(COMMON) do
        if StaticPopupDialogs[n] then add(n) end
    end
    for n in pairs(db.seen) do add(n) end
    for n in pairs(db.skip) do add(n) end
    table.sort(names)

    local width = scroll:GetWidth()
    if not width or width < 100 then width = 500 end
    for i, name in ipairs(names) do
        local row = GetRow(i)
        row.key = name
        row.label:SetText(name)
        row.desc:SetWidth(width - 40)
        row.desc:SetText(Description(name))
        row:SetChecked(db.skip[name] or false)
        row:Show()
    end
    for i = #names + 1, #rows do rows[i]:Hide() end
    content:SetSize(width, math.max(1, #names * ROW_HEIGHT))
end

panel:SetScript("OnShow", Refresh)
scroll:HookScript("OnSizeChanged", function() if panel:IsShown() then Refresh() end end)

local debugBox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
debugBox:SetPoint("BOTTOMLEFT", 12, 14)
local debugLabel = debugBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
debugLabel:SetPoint("LEFT", debugBox, "RIGHT", 4, 0)
debugLabel:SetText("Debug: print popup names as they appear")
debugBox:SetScript("OnClick", function(self) db.debug = self:GetChecked() and true or false end)
panel:HookScript("OnShow", function() debugBox:SetChecked(db and db.debug) end)

-- StatsGraph.lua loads after this file, so look up ns.SetGraphShown when used.
local graphBox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
graphBox:SetPoint("BOTTOMLEFT", debugBox, "TOPLEFT", 0, 0)
local graphLabel = graphBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
graphLabel:SetPoint("LEFT", graphBox, "RIGHT", 4, 0)
graphLabel:SetText("Show FPS and latency graph")
graphBox:SetScript("OnClick", function(self)
    if ns.SetGraphShown then ns.SetGraphShown(self:GetChecked() and true or false) end
end)
panel:HookScript("OnShow", function()
    graphBox:SetShown(ns.SetGraphShown ~= nil)
    graphBox:SetChecked(db and db.graph)
end)

local forget = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
forget:SetSize(170, 22)
forget:SetPoint("BOTTOMRIGHT", -16, 16)
forget:SetText("Forget unchecked")
forget:SetScript("OnClick", function()
    for n in pairs(db.seen) do
        if not db.skip[n] then db.seen[n] = nil end
    end
    Refresh()
end)
forget:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Remove popups you've seen but not checked from this list.", 1, 1, 1, true)
    GameTooltip:Show()
end)
forget:SetScript("OnLeave", GameTooltip_Hide)

local category
local function RegisterPanel()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

local function OpenPanel()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- called twice: the first call can land on the wrong page
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

---------------------------------------------------------------------------
-- Init and slash command
---------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" then
        -- after login (and each /reload), once the chat frame is up
        if ns.ToggleGraph then
            print(PREFIX .. "/pac graph - toggle FPS/latency graph; /pac help - for more")
        else
            print(PREFIX .. "/pac help - for more")
        end
        self:UnregisterEvent("PLAYER_LOGIN")
        return
    end
    if name ~= addonName then return end
    PopupAtCursorDB = PopupAtCursorDB or {}
    db = PopupAtCursorDB
    db.skip = db.skip or {}
    db.seen = db.seen or {}
    db.debug = db.debug or false
    RegisterPanel()
    ns.db = db
    if ns.OnLoaded then ns.OnLoaded(db) end
    self:UnregisterEvent("ADDON_LOADED")
end)

SLASH_POPUPATCURSOR1 = "/pac"
SlashCmdList.POPUPATCURSOR = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "debug" then
        db.debug = not db.debug
        print(PREFIX .. "debug " .. (db.debug and "on" or "off"))
    elseif msg == "graph" and ns.ToggleGraph then
        print(PREFIX .. "stats graph " .. (ns.ToggleGraph() and "shown" or "hidden"))
    elseif msg == "help" then
        print(PREFIX .. "/pac - open options")
        print(PREFIX .. "/pac debug - print popup names as they appear")
        if ns.ToggleGraph then
            print(PREFIX .. "/pac graph - show/hide the FPS + latency graph")
        end
    else
        OpenPanel()
    end
end
