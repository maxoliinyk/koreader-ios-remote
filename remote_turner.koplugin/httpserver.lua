local BaseServer = require("ui/message/simpletcpserver")
local logger = require("logger")

local HTTPServer = {}

function HTTPServer:new(options)
    local server = BaseServer:new(options)
    server.waitEvent = self.waitEvent
    return server
end

function HTTPServer.waitEvent(server)
    local client = server.server:accept()
    if not client then return end
    client:settimeout(0.25, "t")

    local lines = {}
    local content_length = 0
    while true do
        local line = client:receive("*l")
        if not line then client:close(); return end
        if #line > 2048 or #lines > 64 then client:close(); return end
        if line == "" then break end
        table.insert(lines, line)
        local length = line:match("^[Cc]ontent%-[Ll]ength:%s*(%d+)%s*$")
        if length then content_length = tonumber(length) end
    end

    if content_length > 4096 then content_length = 4097 end
    local body = ""
    if content_length > 0 then
        body = client:receive(content_length)
        if not body then client:close(); return end
    end

    local request = table.concat(lines, "\r\n") .. "\r\n\r\n" .. body
    logger.dbg("RemoteTurner: received authenticated request envelope")
    client:settimeout(0.5, "t")
    return server.receiveCallback(request, client)
end

return HTTPServer
