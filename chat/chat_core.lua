-- ==================== ozChat Core Engine ====================
-- Provides pluggable event and display filter pipelines for ChatFrame events and messages.

ozChat = ozChat or {
    eventFilters = {},
    displayFilters = {},
}

function ozChat:regEvtFilter(name, func)
    self.eventFilters[name] = func
end

function ozChat:regDspFilter(name, func)
    self.displayFilters[name] = func
end

function ozChat:buildChatObject(frame, event)
    local chat = {
        frame       = frame,
        frameId     = frame and frame:GetID() or nil,
        event       = event,
        type        = string.sub(event, 10), -- SAY, WHISPER, CHANNEL...
        message     = arg1,
        sender      = arg2,
        language    = arg3,
        channelName = arg4,
        senderFull  = arg5,
        channelNum  = arg8,
        channelId   = arg9,
        cancelled   = false,
        redirect    = 0,
    }
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
                local dspEvent = {
                    frame = frame,
                    msg   = msg,
                    r     = r,
                    g     = g,
                    b     = b,
                    id    = id,
                }
                dspEvent = ozChat:runDspFilter(dspEvent)
                return dspEvent.frame, dspEvent.msg, dspEvent.r, dspEvent.g, dspEvent.b, dspEvent.id
            end)
        end
    end
end
