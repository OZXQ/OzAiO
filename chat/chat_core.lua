-- ==================== ozChat Core Engine ====================
-- Provides pluggable event and display filter pipelines for ChatFrame events and messages.

ozChat = ozChat or {
    eventFilters = {},
    displayFilters = {},
}

-- Chat events fire once per chat window (up to 7) and AddMessage runs for every
-- single chat line, so both pipelines recycle one scratch object instead of
-- allocating a fresh table per call. Filters consume the object synchronously
-- and never keep a reference to it, so sharing is safe.
local evt_scratch = {}
local dsp_scratch = {}
local dsp_busy = false

function ozChat:regEvtFilter(name, func)
    self.eventFilters[name] = func
end

function ozChat:regDspFilter(name, func)
    self.displayFilters[name] = func
end

function ozChat:buildChatObject(frame, event)
    local chat = evt_scratch
    chat.frame       = frame
    chat.frameId     = frame and frame:GetID() or nil
    chat.event       = event
    chat.type        = string.sub(event, 10) -- SAY, WHISPER, CHANNEL...
    chat.message     = arg1
    chat.sender      = arg2
    chat.language    = arg3
    chat.channelName = arg4
    chat.senderFull  = arg5
    chat.channelNum  = arg8
    chat.channelId   = arg9
    chat.cancelled   = false
    chat.redirect    = 0
    return chat
end

function ozChat:runEvtFilter(chatEvent)
    local rtn = chatEvent
    for _, func in pairs(self.eventFilters) do
        rtn = func(rtn)
    end
    return rtn
end

function ozChat:runDspFilter(displayEvent)
    for _, func in pairs(self.displayFilters) do
        displayEvent = func(displayEvent)
    end
    return displayEvent
end

function ozChat:init()
    if self._initialized then return end
    self._initialized = true

    OzHook:hook("ChatFrame_OnEvent", function(event)
        if not event or not string.find(event, "^CHAT_MSG_") then
            return
        end
        local chat = ozChat:buildChatObject(this, event)
        chat = ozChat:runEvtFilter(chat)
        if chat.cancelled then
            return false
        end
        arg1 = chat.message
        arg2 = chat.sender
        arg3 = chat.language
        arg4 = chat.channelName
        arg5 = chat.senderFull
        arg8 = chat.channelNum
        arg9 = chat.channelId
    end)

    for i = 1, NUM_CHAT_WINDOWS do
        local cf = getglobal("ChatFrame" .. i)
        if cf then
            OzHook:hook(cf, "AddMessage", function(frame, msg, r, g, b, id)
                local dspEvent
                if dsp_busy then
                    -- Nested AddMessage (a filter printing to chat): use a fresh
                    -- table so the outer call's scratch object stays intact.
                    dspEvent = { frame = frame, msg = msg, r = r, g = g, b = b, id = id }
                    dspEvent = ozChat:runDspFilter(dspEvent)
                else
                    dsp_busy = true
                    dspEvent = dsp_scratch
                    dspEvent.frame = frame
                    dspEvent.msg   = msg
                    dspEvent.r     = r
                    dspEvent.g     = g
                    dspEvent.b     = b
                    dspEvent.id    = id
                    dspEvent = ozChat:runDspFilter(dspEvent)
                    dsp_busy = false
                end
                return dspEvent.frame, dspEvent.msg, dspEvent.r, dspEvent.g, dspEvent.b, dspEvent.id
            end)
        end
    end
end
