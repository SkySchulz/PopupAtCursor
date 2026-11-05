-- luacheck config: `make lint` runs luacheck on every .lua the .toc loads.
-- WoW runs Lua 5.1; the game's API arrives as globals, listed below.

std = "lua51"
max_line_length = 120

-- Globals the addon creates or writes into.
globals = {
    "PopupAtCursorDB",      -- SavedVariables
    "SLASH_POPUPATCURSOR1",
    "SlashCmdList",
}

-- WoW API the addon reads. Add new ones here as the code starts using them.
read_globals = {
    -- frames and widgets
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "GameTooltip_Hide",

    -- popups
    "StaticPopupDialogs",
    "hooksecurefunc",

    -- options panel (Settings on Retail; InterfaceOptions on older clients)
    "Settings",
    "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame_OpenToCategory",

    -- input and stats
    "GetCursorPosition",
    "IsShiftKeyDown",
    "GetNetStats",
}
