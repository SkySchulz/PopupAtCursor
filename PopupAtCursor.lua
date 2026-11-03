-- Popups that should NEVER move. Empty this table to move literally everything.
-- Use /pac debug to find popup names.
local SKIP = {
    -- PARTY_INVITE = true,
    -- PARTY_INVITE_XREALM = true,
    -- RESURRECT = true,
    -- RESURRECT_NO_SICKNESS = true,
    -- RESURRECT_NO_TIMER = true,
    -- CONFIRM_SUMMON = true,
    -- CONFIRM_SUMMON_SCENARIO = true,
    -- CONFIRM_SUMMON_STARTING_AREA = true,
    -- DUEL_REQUESTED = true,
    -- TRADE = true,
    -- DEATH = true,
    -- CAMP = true,
    -- QUIT = true,
    -- INSTANCE_BOOT = true,
    -- INSTANCE_LOCK = true,
}

local debug = false

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
    if not which then return end
    for i = 1, 4 do
        local f = _G["StaticPopup" .. i]
        if f and f:IsShown() and f.which == which then
            if debug then print("|cff33ff99PopupAtCursor:|r popup = " .. which) end
            if not SKIP[which] then
                MoveToCursor(f)
            end
            return
        end
    end
end)

SLASH_POPUPATCURSOR1 = "/pac"
SlashCmdList.POPUPATCURSOR = function(msg)
    if msg == "debug" then
        debug = not debug
        print("|cff33ff99PopupAtCursor:|r debug " .. (debug and "on" or "off"))
    else
        print("|cff33ff99PopupAtCursor:|r /pac debug - print popup names as they appear")
    end
end
