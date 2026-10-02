-- OzHook: lightweight hook library for WoW 1.12
--
-- One API for global functions, methods, and frame scripts.
-- Everything goes through: wrapper → pre → original → post.
-- Auto-detects scripts (obj has GetScript, name starts with "On", no table method).
--
-- API:
--   OzHook:hook(target, preFn [, postFn])
--     preFn  — runs before original. return false to cancel. nil to skip.
--     postFn — runs after original. nil to skip.
--   OzHook:unhook(target, fn)  — remove fn from pre or post list. restores original if empty.

local MAJOR = "OzHook-1.0"
local MINOR = 1

if OzHook and OzHook.version and OzHook.version >= MINOR then
    return
end

OzHook = OzHook or {}
OzHook.version = MINOR
OzHook._registry = OzHook._registry or {}

local _G = getfenv(0)

local function isScriptTarget(obj, name)
    return type(obj) == "table"
        and type(obj.GetScript) == "function"
        and type(name) == "string"
        and string.sub(name, 1, 2) == "On"
        and obj[name] == nil
end

local function getOrig(obj, name)
    if obj == nil then return _G[name] end
    if type(obj) == "string" then return _G[obj] end
    if isScriptTarget(obj, name) then return obj:GetScript(name) end
    return obj[name]
end

local function installHook(obj, name, fn)
    if obj == nil then
        _G[name] = fn
    elseif type(obj) == "string" then
        _G[obj] = fn
    elseif isScriptTarget(obj, name) then
        obj:SetScript(name, fn)
    else
        obj[name] = fn
    end
end

local function regKey(obj, name)
    if obj == nil then
        return "_G:" .. name
    end
    if type(obj) == "string" then
        return "_G:" .. obj
    end
    return obj
end

-- Wrappers sit on the hottest paths in the client (a chat event fires once per
-- chat window, AddMessage once per chat line), so a call must not allocate.
--
-- Lua 5.0 has no `...` *expression*, and a vararg function makes the VM build
-- an `arg` table on every single call, so the wrapper keeps a fixed parameter
-- list and forwards arguments by value. The ten slots cover every hook target
-- in this addon (widest: ChatFrame:AddMessage(frame, msg, r, g, b, id)
-- with 6); unused slots are plain nil, which these APIs cannot tell apart from
-- "not passed". Forwarding positionally also stops a nil in the middle from
-- truncating the tail the way unpack()/getn() did.
local function createWrapper(entry)
    local orig = entry.orig
    local pre = entry.pre
    local post = entry.post
    -- Reused buffer for a pre-hook that replaces the argument list. Lua pads a
    -- multiple assignment with nils, so this never needs clearing.
    local ret = {}

    return function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        -- Prevent recursive hook execution
        if entry.running then
            return orig(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        end

        entry.running = true

        ----------------------------------------------------------------
        -- Pre hooks
        -- return false      -> cancel original call
        -- return nil        -> leave arguments unchanged
        -- return (...)      -> replace arguments
        ----------------------------------------------------------------
        for i = 1, table.getn(pre) do
            ret[1], ret[2], ret[3], ret[4], ret[5],
            ret[6], ret[7], ret[8], ret[9], ret[10] =
                pre[i](a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)

            if ret[1] == false then
                entry.running = nil
                return
            end

            if ret[1] ~= nil then
                a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 =
                    ret[1], ret[2], ret[3], ret[4], ret[5],
                    ret[6], ret[7], ret[8], ret[9], ret[10]
            end
        end

        ----------------------------------------------------------------
        -- Original function
        ----------------------------------------------------------------
        if table.getn(post) == 0 then
            -- No post hooks: return the original results straight through
            -- instead of packing them into a throwaway table.
            entry.running = nil
            return orig(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        end

        local results = {
            orig(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        }

        ----------------------------------------------------------------
        -- Post hooks
        -- Receive the final arguments (same API as before)
        ----------------------------------------------------------------
        for i = 1, table.getn(post) do
            post[i](a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        end

        entry.running = nil

        return unpack(results)
    end
end

local function ensureHooked(obj, name)
    local k = regKey(obj, name)
    if not OzHook._registry[k] then OzHook._registry[k] = {} end
    local entry = OzHook._registry[k][name]
    if entry then return entry end

    local orig = getOrig(obj, name)
    local isScript = isScriptTarget(obj, name)

    if not isScript and orig == nil then
        error("[OzHook] " .. tostring(name) .. " is not a function (got nil)", 2)
    end

    entry = {
        owner = obj,
        name  = name,
        orig  = orig or function() end,
        pre   = {},
        post  = {},
    }
    entry.wrapper = createWrapper(entry)
    installHook(obj, name, entry.wrapper)
    OzHook._registry[k][name] = entry
    return entry
end

local function hasFn(list, fn)
    for _, f in ipairs(list) do
        if f == fn then return true end
    end
    return false
end

-- OzHook:hook("ChatFrame_OnEvent", preFn)
-- OzHook:hook("ChatFrame_OnEvent", preFn, postFn)
-- OzHook:hook("ChatFrame_OnEvent", nil, postFn)
-- OzHook:hook(GameTooltip, "AddMessage", preFn)
-- OzHook:hook(frame, "OnShow", preFn, postFn)
function OzHook:hook(obj, name, preFn, postFn)
    if type(obj) == "string" then
        obj, name, preFn, postFn = nil, obj, name, preFn
    end
    local entry = ensureHooked(obj, name)
    if preFn and not hasFn(entry.pre, preFn) then
        table.insert(entry.pre, preFn)
    end
    if postFn and not hasFn(entry.post, postFn) then
        table.insert(entry.post, postFn)
    end
end

-- Remove fn from pre or post list. Restores original and cleans up registry when empty.
-- OzHook:unhook("ChatFrame_OnEvent", fn)
-- OzHook:unhook(GameTooltip, "AddMessage", fn)
function OzHook:unhook(obj, name, fn)
    if type(obj) == "string" then
        fn = name
        name = obj
        obj = nil
    end
    local k = regKey(obj, name)
    local entry = OzHook._registry[k] and OzHook._registry[k][name]
    if not entry then return end

    for i, f in ipairs(entry.pre) do
        if f == fn then
            table.remove(entry.pre, i); break
        end
    end
    for i, f in ipairs(entry.post) do
        if f == fn then
            table.remove(entry.post, i); break
        end
    end

    if not next(entry.pre) and not next(entry.post) then
        installHook(obj, name, entry.orig)
        OzHook._registry[k][name] = nil
        if not next(OzHook._registry[k]) then
            OzHook._registry[k] = nil
        end
    end
end

-- Restore all originals and clear the registry.
function OzHook:unhookAll()
    for _, methods in pairs(OzHook._registry) do
        for _, entry in pairs(methods) do
            installHook(entry.owner, entry.name, entry.orig)
        end
    end
    OzHook._registry = {}
end

-- Check if a target is hooked, or if a specific fn is registered.
-- OzHook:isHooked("ChatFrame_OnEvent")           — true if any hook exists
-- OzHook:isHooked("ChatFrame_OnEvent", fn)       — true if fn is in pre or post list
-- OzHook:isHooked(GameTooltip, "AddMessage")
-- OzHook:isHooked(frame, "OnShow")
function OzHook:isHooked(obj, name, fn)
    if type(obj) == "string" then
        fn = name
        name = obj
        obj = nil
    end
    local k = regKey(obj, name)
    local entry = OzHook._registry[k] and OzHook._registry[k][name]
    if not entry then return false end
    if not fn then return true end
    return hasFn(entry.pre, fn) or hasFn(entry.post, fn)
end
