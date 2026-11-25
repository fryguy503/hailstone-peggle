-- Copyright 2026 fryguy503. All rights reserved. See LICENSE.
local ScoreChat = {
    channels = {
        {id = "group", label = "Group"},
        {id = "guild", label = "Guild"},
        {id = "raid", label = "Raid"},
        {id = "say", label = "Say"},
    },
}

local commands = {group = "/gsay", guild = "/guildsay", raid = "/rsay", say = "/say"}

local function validName(value)
    return type(value) == "string" and #value <= 60 and value:match("^[A-Za-z0-9][A-Za-z0-9 '%-]*$") ~= nil
end

function ScoreChat.format(record)
    if type(record) ~= "table" or not validName(record.boardName) or not validName(record.modeName) then
        return nil, "Select a board and mode with a recorded score."
    end
    local score = record.score
    if type(score) ~= "number" or not (score >= 0 and score <= 1000000000 and score == math.floor(score)) then
        return nil, "Select a completed score."
    end
    local grouped = tostring(math.floor(score)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return string.format("[Peggle] Personal best of %s on %s (%s).", grouped, record.boardName, record.modeName)
end

function ScoreChat.send(mq, channel, record)
    local command = commands[channel]
    if not command then return nil, "Choose Group, Guild, Raid, or Say." end
    local line, err = ScoreChat.format(record)
    if not line then return nil, err end
    if type(mq) ~= "table" or not pcall(mq.cmd, command .. " " .. line) then
        return nil, "Could not submit the score to chat."
    end
    return true
end

return ScoreChat
