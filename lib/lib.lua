if not OzLib then 
    OzLib = {
        -- print()      print colored message to chat
        -- argCheck()   check function arguments
        -- convertMoney()   convert money to G, S, C format
    }
end

local INFO_LEVEL = {
    ["error"] = 3,
    ["debug"] = 2,
    ["default"] = 1
}

local PRINT_COLOR = {
    ["error"] = "|CFFFF0000",
    ["debug"] = "|CFF0000CD",
    ["default"] = "|CFF20B2AA"
}

function OzLib:print(msg, type)
    if INFO_LEVEL[type or "default"] <= INFO_LEVEL[OZAIO.info_level or "default"] then
        return
    end

    local prefix = PRINT_COLOR[type or "default"] .. "[OZAIO] "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. msg)
end

function OzLib:argCheck(value, argNum, ...)
    local vtype = type(value)
    for i = 1, table.getn(arg) do
        if vtype == arg[i] or (arg[i] == "nil" and value == nil) then
            return
        end
    end
    local expected = table.concat(arg, " or ")
    error(string.format("[OzHook] Bad argument #%d (expected %s, got %s)", argNum, expected, vtype), 3)
end

function OzLib:convertMoney(money)
    local m = abs(money)

    local gold = math.floor(m / 10000)
    local silver = math.floor(math.mod(m, 10000) / 100)
    local copper = math.mod(m, 100)

    local win = true
    if money < 0 then
        win = false
    end

    return win, gold, silver, copper, string.format(
        "|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r",
        gold, silver, copper
    )
end

-- Item quality → RGB color mapping
OzLib.ITEM_QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },  -- Poor (grey)
    [1] = { 1, 1, 1 },            -- Common (white)
    [2] = { 0.12, 1, 0 },         -- Uncommon (green)
    [3] = { 0.27, 0.51, 1 },      -- Rare (blue)
    [4] = { 0.64, 0.21, 0.93 },   -- Epic (purple)
    [5] = { 1, 0.50, 0 },         -- Legendary (orange)
}

-- Returns r, g, b matching the item's quality
function OzLib:itemQualityColor(id)
    local itemID = tonumber(id)
    if not itemID and type(id) == "string" then
        local _, _, linkID = string.find(id, "item:(%d+)")
        itemID = tonumber(linkID)
    end
    if not itemID then return 1, 1, 1 end
    local _, _, quality = GetItemInfo(itemID)
    local c = OzLib.ITEM_QUALITY_COLORS[quality] or OzLib.ITEM_QUALITY_COLORS[1]
    return c[1], c[2], c[3]
end

