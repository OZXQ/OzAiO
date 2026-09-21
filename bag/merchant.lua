local LOCALE = GetLocale()
local L = setmetatable({}, {
    __index = function(t, k)
        local v = tostring(k)
        rawset(t, k, v)
        return v
    end
})
if LOCALE == "zhCN" then
    L["Bag/Vendor"] = "背包/商人"
    L["Auto Sell Junk"] = "自动出售垃圾物品"
    L["Auto Buy Items"] = "自动购买物品"
    L["Auto Sell Items"] = "自动出售物品"
    L["Buy List"] = "购买列表"
    L["Sell List"] = "出售列表"
    L["Total items"] = "总计"
    L["No items added"] = "未添加任何物品"
    L["Item already in list"] = "物品已在列表中"
    L["Item not in list"] = "物品不在列表中"
    L["Bags full, stop buying"] = "背包已满，停止购买"
    L["Not enough money for"] = "金币不足，停止购买"
    L["Bought"] = "购买"
    L["gain "] = "获得"
    L["spend "] = "花费"
    L["Buy plan:"] = "购买计划:"
    L["will buy %s x%d (have %d, target %d)"] = "将购买 %s x%d (已有%d, 目标%d)"
    L["nothing to buy"] = "无需购买任何物品"
    L["Item not found"] = "未找到物品"
    L["Item ID / Link"] = "物品ID/链接"
    L["Automatically sells grey items when visiting a merchant."] = "访问商人时自动出售所有灰色(垃圾)品质物品。"
    L["Automatically sells custom blacklisted items when visiting a merchant."] = "访问商人时自动出售自定义列表中的物品。"
    L["Automatically restocks reagents/items up to configured quantities."] = "访问商人时自动补齐指定物品至目标数量。"
end

local function is_enabled(val)
    return val == true or val == 1
end

local ozBag = {
    event_frame = nil,
    money = 0,
    next_tick = 0,
    merchant_opened = false,
    inventory = nil,
}

-- Centralized item-link parsing (all item parsers go through this)
function ozBag:GetItemIDFromLink(link)
    if not link then return nil end
    local _, _, id = string.find(link, "item:(%d+)")
    return tonumber(id)
end

-- Snapshot inventory once per merchant open; invalidated by BAG_UPDATE so
-- repeated countItemInBags() calls during queue planning stay O(1).
function ozBag:buildInventoryCache()
    self.inventory = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            local id = self:GetItemIDFromLink(link)
            if id then
                local _, count = GetContainerItemInfo(bag, slot)
                self.inventory[id] = (self.inventory[id] or 0) + (count or 1)
            end
        end
    end
end

function ozBag:collect_grey_items()
    local grey_items = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local texture, itemCount, locked = GetContainerItemInfo(bag, slot)
            if texture and not locked then
                local link = GetContainerItemLink(bag, slot)
                if link and string.find(string.lower(link), "ff9d9d9d", 1, true) then
                    local id = self:GetItemIDFromLink(link)
                    table.insert(grey_items, {bag = bag, slot = slot, id = id})
                end
            end
        end
    end
    return grey_items
end

-- ================== Helpers ==================

function ozBag:countItemInBags(itemID)
    if not self.inventory then
        self:buildInventoryCache()
    end
    return self.inventory[itemID] or 0
end

function ozBag:hasSpaceForItem(itemID)
    -- Only an empty slot, or a partially filled stack of THIS item, counts as space.
    local _, _, _, _, _, _, stackCount = GetItemInfo(itemID)
    local maxStack = tonumber(stackCount) or 20
    if maxStack <= 0 then maxStack = 20 end

    for bag = 0, NUM_BAG_SLOTS do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if not link then
                return true
            end
            if self:GetItemIDFromLink(link) == itemID then
                local _, itemCount = GetContainerItemInfo(bag, slot)
                if (itemCount or 0) < maxStack then
                    return true
                end
            end
        end
    end
    return false
end

-- ================== Unified Merchant Tick ==================

local function stop_tick()
    if ozBag.event_frame then
        ozBag.event_frame:SetScript("OnUpdate", nil)
    end
end

-- Confirm a completed merchant purchase (called once the bought stack has
-- actually arrived via BAG_UPDATE) and advance the buy queue.
local function commit_buy(plan)
    plan.buyTimes = plan.buyTimes - 1
    plan.need = plan.need - (plan.stackQty or 1)

    -- Track for summary
    if not ozBag.buy_summary then ozBag.buy_summary = {} end
    if not ozBag.buy_summary[plan.itemID] then
        ozBag.buy_summary[plan.itemID] = { count = 0, cost = 0 }
    end
    ozBag.buy_summary[plan.itemID].count = ozBag.buy_summary[plan.itemID].count + (plan.stackQty or 1)
    ozBag.buy_summary[plan.itemID].cost = ozBag.buy_summary[plan.itemID].cost + plan.price

    if plan.buyTimes <= 0 or plan.need <= 0 then
        table.remove(ozBag.buy_queue, 1)
        if table.getn(ozBag.buy_queue) == 0 then
            ozBag.buy_queue = nil
            stop_tick()
        end
    end
end

local function on_merchant_tick()
    if GetTime() < ozBag.next_tick then return end
    ozBag.next_tick = GetTime() + 0.2

    -- Priority 1: Sell queued items (grey + auto-sell list)
    if ozBag.sell_queue and table.getn(ozBag.sell_queue) > 0 then
        local item = table.remove(ozBag.sell_queue, 1)
        local texture, _, locked = GetContainerItemInfo(item.bag, item.slot)
        if texture and not locked then
            local currentLink = GetContainerItemLink(item.bag, item.slot)
            local currentID = ozBag:GetItemIDFromLink(currentLink)
            if currentID and (item.id == nil or currentID == item.id) then
                UseContainerItem(item.bag, item.slot)
            end
        end
        if table.getn(ozBag.sell_queue) == 0 then
            ozBag.sell_queue = nil
        end
        return
    end

    -- Priority 2: Buy queued items
    if ozBag.buy_queue and table.getn(ozBag.buy_queue) > 0 then
        local plan = ozBag.buy_queue[1]

        -- A purchase was issued but its BAG_UPDATE hasn't arrived yet
        if ozBag.buy_pending then
            -- Give up if the item never landed (stock changed / failed buy)
            if GetTime() >= ozBag.buy_pending_at then
                ozBag.buy_pending = false
                table.remove(ozBag.buy_queue, 1)
                if table.getn(ozBag.buy_queue) == 0 then
                    ozBag.buy_queue = nil
                    stop_tick()
                end
            end
            return
        end

        if plan.need <= 0 then
            table.remove(ozBag.buy_queue, 1)
            if table.getn(ozBag.buy_queue) == 0 then
                ozBag.buy_queue = nil
                stop_tick()
            end
            return
        end

        -- Check bag space for this specific item
        if not ozBag:hasSpaceForItem(plan.itemID) then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[OzAiO] " .. L["Bags full, stop buying"] .. "|r")
            ozBag.buy_queue = nil
            stop_tick()
            return
        end

        -- Check money
        if GetMoney() < plan.price then
            local name = GetItemInfo(plan.itemID) or ("[" .. tostring(plan.itemID) .. "]")
            DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[OzAiO] " .. L["Not enough money for"] .. " " .. name .. "|r")
            table.remove(ozBag.buy_queue, 1)
            if table.getn(ozBag.buy_queue) == 0 then
                ozBag.buy_queue = nil
                stop_tick()
            end
            return
        end

        BuyMerchantItem(plan.slot)
        -- Don't count the purchase yet: wait for BAG_UPDATE to confirm the
        -- item actually arrived (stock change / lag / failed buy detection)
        ozBag.buy_pending = true
        ozBag.buy_pending_at = GetTime() + 2
        return
    end

    -- All done
    stop_tick()
end

-- ================== action_onshow / action_onclose ==================

function ozBag:action_onshow()
    -- Reset state
    self.sell_queue = {}
    self.buy_queue = nil
    self.buy_summary = nil
    self.buy_pending = false
    -- Snapshot inventory once; kept fresh via BAG_UPDATE
    self:buildInventoryCache()

    -- Collect grey items (sell_junk)
    if is_enabled(OZAIO_CONFIG["bag.sell_junk"]) then
        local grey = self:collect_grey_items()
        for _, item in ipairs(grey) do
            table.insert(self.sell_queue, item)
        end
    end

    -- Collect auto-sell list items (deduped against grey items already queued)
    if is_enabled(OZAIO_CONFIG["bag.auto_sell"]) then
        local sellList = OZAIO_CONFIG["bag.auto_sell_list"] or {}
        local queued = {}
        -- Mark grey items already in queue
        for _, item in ipairs(self.sell_queue) do
            queued[item.bag .. ":" .. item.slot] = true
        end
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, GetContainerNumSlots(bag) do
                local texture, _, locked = GetContainerItemInfo(bag, slot)
                if texture and not locked then
                    local key = bag .. ":" .. slot
                    if not queued[key] then
                        local link = GetContainerItemLink(bag, slot)
                        if link then
                            local id = ozBag:GetItemIDFromLink(link)
                            if id and sellList[id] then
                                table.insert(self.sell_queue, {bag = bag, slot = slot, id = id})
                                queued[key] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- Build buy queue (auto_buy)
    if is_enabled(OZAIO_CONFIG["bag.auto_buy"]) then
        local buyList = OZAIO_CONFIG["bag.auto_buy_list"] or {}
        local numItems = GetMerchantNumItems()

        -- Print buy plan
        local hasPlan = false
        for itemID, targetQty in pairs(buyList) do
            if type(targetQty) == "number" and targetQty > 0 then
                local have = self:countItemInBags(itemID)
                local need = targetQty - have
                if need > 0 then
                    if not hasPlan then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff20b2aa[OzAiO] " .. L["Buy plan:"] .. "|r")
                        hasPlan = true
                    end
                    local name = GetItemInfo(itemID) or ("[" .. tostring(itemID) .. "]")
                    DEFAULT_CHAT_FRAME:AddMessage("  " .. string.format(
                        L["will buy %s x%d (have %d, target %d)"], name, need, have, targetQty))
                end
            end
        end
        if not hasPlan then
            DEFAULT_CHAT_FRAME:AddMessage("|cff20b2aa[OzAiO] " .. L["nothing to buy"] .. "|r")
        end

        -- Build queue
        self.buy_queue = {}
        self.buy_summary = {}
        for itemID, targetQty in pairs(buyList) do
            if type(targetQty) == "number" and targetQty > 0 then
                local have = self:countItemInBags(itemID)
                local need = targetQty - have
                if need > 0 then
                    -- Pick the cheapest matching merchant entry (some vendors
                    -- list the same item at different prices / limited stock)
                    local bestSlot, bestPrice, stackQty
                    for i = 1, numItems do
                        local link = GetMerchantItemLink(i)
                        if link then
                            local merchantID = self:GetItemIDFromLink(link)
                            if merchantID == itemID then
                                local _, _, price, qty = GetMerchantItemInfo(i)
                                if price and price > 0 and (not bestPrice or price < bestPrice) then
                                    bestSlot = i
                                    bestPrice = price
                                    stackQty = qty or 1
                                end
                            end
                        end
                    end
                    if bestSlot then
                        -- Buy only as many merchant stacks as needed (rounded up)
                        local buyTimes = math.ceil(need / stackQty)
                        table.insert(self.buy_queue, {
                            itemID = itemID,
                            slot = bestSlot,
                            need = need,
                            price = bestPrice,
                            stackQty = stackQty,
                            buyTimes = buyTimes,
                        })
                    end
                end
            end
        end
        if table.getn(self.buy_queue) == 0 then
            self.buy_queue = nil
        end
    end

    -- Start tick if there's work to do
    local hasSellWork = self.sell_queue and table.getn(self.sell_queue) > 0
    local hasBuyWork = self.buy_queue and table.getn(self.buy_queue) > 0
    if hasSellWork or hasBuyWork then
        self.next_tick = 0
        self.event_frame:SetScript("OnUpdate", on_merchant_tick)
    end
end

function ozBag:clearQueue()
    stop_tick()
    self.sell_queue = nil
    self.buy_queue = nil
    self.buy_summary = nil
    self.buy_pending = false
end

function ozBag:action_onclose()
    stop_tick()

    local buySummary = self.buy_summary

    self:clearQueue()
    self.merchant_opened = false

    -- Buy summary
    if buySummary and next(buySummary) then
        for itemID, data in pairs(buySummary) do
            if data.count > 0 then
                local name = GetItemInfo(itemID) or ("[" .. tostring(itemID) .. "]")
                local _, _, _, _, costStr = OzLib:convertMoney(-data.cost)
                DEFAULT_CHAT_FRAME:AddMessage("|cff20b2aa[OzAiO] " .. L["Bought"] .. " " .. name .. " x" .. data.count
                    .. " (" .. L["spend "] .. costStr .. ")|r")
            end
        end
    end

    local m = GetMoney() - self.money
    if m ~= 0 then
        local win, _, _, _, moneyStr = OzLib:convertMoney(m)
        local wl = win and L["gain "] or L["spend "]
        DEFAULT_CHAT_FRAME:AddMessage("|cff20b2aa[OzAiO] " .. wl .. moneyStr .. "|r")
    end
end

-- ================== Toggle ==================

function ozBag:updateToggle()
    local sellOn = is_enabled(OZAIO_CONFIG["bag.sell_junk"])
    local autoSellOn = is_enabled(OZAIO_CONFIG["bag.auto_sell"])
    local autoBuyOn = is_enabled(OZAIO_CONFIG["bag.auto_buy"])
    local shouldRun = sellOn or autoSellOn or autoBuyOn

    if not self.event_frame then
        self.event_frame = CreateFrame("Frame", "OzBagMerchantFrame", UIParent)
        self.event_frame:SetScript("OnEvent", function()
            if event == "MERCHANT_SHOW" then
                if ozBag.merchant_opened then return end
                ozBag.money = GetMoney()
                ozBag.merchant_opened = true
                ozBag:action_onshow()
            elseif event == "MERCHANT_CLOSED" then
                if ozBag.merchant_opened then
                    ozBag:action_onclose()
                end
            elseif event == "BAG_UPDATE" then
                -- Bag contents changed: drop the inventory snapshot and
                -- confirm a pending merchant purchase once it really landed
                ozBag.inventory = nil
                if ozBag.buy_pending
                    and ozBag.buy_queue
                    and table.getn(ozBag.buy_queue) > 0 then
                    ozBag.buy_pending = false
                    commit_buy(ozBag.buy_queue[1])
                end
            end
        end)
    end

    self.event_frame:UnregisterAllEvents()
    if shouldRun then
        self.event_frame:RegisterEvent("MERCHANT_SHOW")
        self.event_frame:RegisterEvent("MERCHANT_CLOSED")
        self.event_frame:RegisterEvent("BAG_UPDATE")
    end
end

-- ==================== Item Resolution Helpers ====================

local function resolveItemInput(text)
    if not text or text == "" then return nil end
    -- Try item link: |cff9d9d9d|Hitem:12345:...|h[Name]|h|r
    local _, _, linkID = string.find(text, "|Hitem:(%d+)")
    if linkID then
        local id = tonumber(linkID)
        local name = GetItemInfo(id)
        return id, name or ("[" .. tostring(id) .. "]")
    end
    -- Try numeric ID
    local id = tonumber(text)
    if id then
        local name = GetItemInfo(id)
        if name then
            return id, name
        else
            return id, "[" .. tostring(id) .. "]"
        end
    end
    -- Try name search in bags
    local textLower = string.lower(text)
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, _, itemName = string.find(link, "%[([^%]]+)%]")
                if itemName and string.find(string.lower(itemName), textLower, 1, true) then
                    local foundID = ozBag:GetItemIDFromLink(link)
                    if foundID then
                        return foundID, itemName
                    end
                end
            end
        end
    end
    -- Try name search at current merchant (item may not be in bags yet)
    local numMerchantItems = GetMerchantNumItems()
    if numMerchantItems and numMerchantItems > 0 then
        for i = 1, numMerchantItems do
            local link = GetMerchantItemLink(i)
            if link then
                local _, _, itemName = string.find(link, "%[([^%]]+)%]")
                if itemName and string.find(string.lower(itemName), textLower, 1, true) then
                    local foundID = ozBag:GetItemIDFromLink(link)
                    if foundID then
                        return foundID, itemName
                    end
                end
            end
        end
    end
    return nil
end

local function itemDisplayName(id)
    local itemID = tonumber(id)
    if not itemID then
        itemID = ozBag:GetItemIDFromLink(id)
    end
    if itemID then
        local name = GetItemInfo(itemID)
        return (name or ("[" .. tostring(itemID) .. "]")) .. " [" .. tostring(itemID) .. "]"
    else
        return tostring(id)
    end
end

-- ==================== Declarative Config UI ====================

local function build_bag_config_ui(panel)
    local parent = panel.scrollChild

    -- Shared widgets for sell section
    local sellList = OzUIHelper:createScrollItemList(parent, {
        height = 70,
        showQuantity = false,
        emptyText = L["No items added"],
        totalPrefix = L["Total items"] .. ": ",
        nameResolver = itemDisplayName,
        colorResolver = OzLib.itemQualityColor,
        getItems = function()
            return OZAIO_CONFIG["bag.auto_sell_list"] or {}
        end,
    })

    local sellEdit = OzUIHelper:createEditBox(parent, 120, 20)

    local function add_sell_item()
        local text = sellEdit:GetText()
        if not text or text == "" then return end
        local itemID, itemName = resolveItemInput(text)
        if not itemID then
            OzLib.print(L["Item not found"], "error")
            return
        end
        if not OZAIO_CONFIG["bag.auto_sell_list"] then
            OZAIO_CONFIG["bag.auto_sell_list"] = {}
        end
        if OZAIO_CONFIG["bag.auto_sell_list"][itemID] then
            OzLib.print(L["Item already in list"] .. ": " .. (itemName or tostring(itemID)), "error")
            return
        end
        OZAIO_CONFIG["bag.auto_sell_list"][itemID] = true
        sellEdit:SetText("")
        sellList:refresh()
    end

    local function del_sell_item()
        local text = sellEdit:GetText()
        if not text or text == "" then return end
        local itemID = resolveItemInput(text)
        if not itemID then
            OzLib.print(L["Item not found"], "error")
            return
        end
        if OZAIO_CONFIG["bag.auto_sell_list"] and OZAIO_CONFIG["bag.auto_sell_list"][itemID] then
            OZAIO_CONFIG["bag.auto_sell_list"][itemID] = nil
            sellEdit:SetText("")
            sellList:refresh()
        else
            OzLib.print(L["Item not in list"] .. ": " .. tostring(itemID), "error")
        end
    end

    sellEdit:SetScript("OnEnterPressed", function()
        add_sell_item()
        this:ClearFocus()
    end)

    -- Shared widgets for buy section
    local buyList = OzUIHelper:createScrollItemList(parent, {
        height = 70,
        showQuantity = true,
        emptyText = L["No items added"],
        totalPrefix = L["Total items"] .. ": ",
        nameResolver = itemDisplayName,
        colorResolver = OzLib.itemQualityColor,
        getItems = function()
            return OZAIO_CONFIG["bag.auto_buy_list"] or {}
        end,
    })

    local buyEdit = OzUIHelper:createEditBox(parent, 120, 20)
    local buyQtyEdit = OzUIHelper:createEditBox(parent, 36, 20)
    buyQtyEdit:SetText("1")

    local function add_buy_item()
        local text = buyEdit:GetText()
        if not text or text == "" then return end
        local itemID, itemName = resolveItemInput(text)
        if not itemID then
            OzLib.print(L["Item not found"], "error")
            return
        end
        local qty = tonumber(buyQtyEdit:GetText()) or 1
        if qty <= 0 then qty = 1 end
        if not OZAIO_CONFIG["bag.auto_buy_list"] then
            OZAIO_CONFIG["bag.auto_buy_list"] = {}
        end
        if OZAIO_CONFIG["bag.auto_buy_list"][itemID] then
            OzLib.print(L["Item already in list"] .. ": " .. (itemName or tostring(itemID)), "error")
            return
        end
        OZAIO_CONFIG["bag.auto_buy_list"][itemID] = qty
        buyEdit:SetText("")
        buyQtyEdit:SetText("1")
        buyList:refresh()
    end

    local function del_buy_item()
        local text = buyEdit:GetText()
        if not text or text == "" then return end
        local itemID = resolveItemInput(text)
        if not itemID then
            OzLib.print(L["Item not found"], "error")
            return
        end
        if OZAIO_CONFIG["bag.auto_buy_list"] and OZAIO_CONFIG["bag.auto_buy_list"][itemID] then
            OZAIO_CONFIG["bag.auto_buy_list"][itemID] = nil
            buyEdit:SetText("")
            buyList:refresh()
        else
            OzLib.print(L["Item not in list"] .. ": " .. tostring(itemID), "error")
        end
    end

    buyEdit:SetScript("OnEnterPressed", function()
        add_buy_item()
        this:ClearFocus()
    end)
    buyQtyEdit:SetScript("OnEnterPressed", function()
        add_buy_item()
        this:ClearFocus()
    end)

    return {
        {
            type = "checkbox",
            label = L["Auto Sell Junk"],
            tooltip = L["Automatically sells grey items when visiting a merchant."],
            config_key = "bag.sell_junk",
            onChange = function(checked)
                ozBag:updateToggle()
            end,
        },
        {
            type = "checkbox",
            label = L["Auto Sell Items"],
            tooltip = L["Automatically sells custom blacklisted items when visiting a merchant."],
            config_key = "bag.auto_sell",
            onChange = function(checked)
                ozBag:updateToggle()
            end,
        },
        { type = "separator" },
        {
            type = "row",
            items = {
                { type = "label", label = L["Sell List"] .. ":", font = "GameFontNormalSmall" },
                { type = "custom", create = function() return sellList.totalLabel end },
            },
        },
        {
            type = "row",
            items = {
                { type = "label", label = L["Item ID / Link"] .. ":", font = "GameFontNormalSmall" },
                { type = "custom", create = function() return sellEdit end },
                { type = "button", label = "+", width = 20, height = 20, func = add_sell_item },
                { type = "button", label = "-", width = 20, height = 20, func = del_sell_item },
            },
        },
        {
            type = "custom",
            height = 70,
            fullWidth = true,
            create = function()
                sellList:refresh()
                return sellList.scrollFrame
            end,
        },
        { type = "space", height = 4 },
        {
            type = "checkbox",
            label = L["Auto Buy Items"],
            tooltip = L["Automatically restocks reagents/items up to configured quantities."],
            config_key = "bag.auto_buy",
            onChange = function(checked)
                ozBag:updateToggle()
            end,
        },
        { type = "separator" },
        {
            type = "row",
            items = {
                { type = "label", label = L["Buy List"] .. ":", font = "GameFontNormalSmall" },
                { type = "custom", create = function() return buyList.totalLabel end },
            },
        },
        {
            type = "row",
            items = {
                { type = "label", label = L["Item ID / Link"] .. ":", font = "GameFontNormalSmall" },
                { type = "custom", create = function() return buyEdit end },
                { type = "label", label = "Qty:", font = "GameFontNormalSmall" },
                { type = "custom", create = function() return buyQtyEdit end },
                { type = "button", label = "+", width = 20, height = 20, func = add_buy_item },
                { type = "button", label = "-", width = 20, height = 20, func = del_buy_item },
            },
        },
        {
            type = "custom",
            height = 70,
            fullWidth = true,
            create = function()
                buyList:refresh()
                return buyList.scrollFrame
            end,
        },
    }
end

-- ==================== Module Registration ====================

local module = OzFramework:registerMod({
    name = "oz_bag",
    title = L["Bag/Vendor"],
    category = "Bag",
    order = 1,
    enabled = true,
    config = {
        ["bag.sell_junk"] = true,
        ["bag.auto_sell"] = false,
        ["bag.auto_sell_list"] = {},
        ["bag.auto_buy"] = false,
        ["bag.auto_buy_list"] = {},
    },
    config_ui_creator = build_bag_config_ui,
    enable = function(self)
        ozBag:updateToggle()
    end,
    disable = function(self)
        if ozBag.event_frame then
            ozBag.event_frame:UnregisterAllEvents()
        end
        ozBag:clearQueue()
    end,
})
