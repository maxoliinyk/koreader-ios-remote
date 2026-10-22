local BaseServer = require("ui/message/simpletcpserver")
local socket = require("socket")

local HTTPServer = {}

function HTTPServer:new(options)
    local server = BaseServer:new(options)
    server.waitEvent = self.waitEvent
    return server
end

function HTTPServer.waitEvent(server)
    local client = server.server:accept()
    if not client then return end
    -- One deadline for the whole request, including slow or incomplete headers.
    local deadline = socket.gettime() + 0.25
    local function receive(count)
        local remaining = deadline - socket.gettime()
        if remaining <= 0 then return nil end
        client:settimeout(remaining, "t")
        return client:receive(count)
    end
    local function reject(status, message)
        client:settimeout(0.5, "t")
        return server.rejectCallback(client, status, message)
    end

    local lines, bytes, content_length = {}, 0, nil
    while true do
        local characters = {}
        while true do
            local character = receive(1)
            if not character then client:close(); return end
            bytes = bytes + 1
            if bytes > 8192 or #characters >= 2048 then
                return reject(413, "Request headers too large")
            end
            if character == "\n" then break end
            characters[#characters + 1] = character
        end
        local line = table.concat(characters):gsub("\r$", "")
        if line == "" then break end
        if #lines >= 64 then return reject(413, "Too many request headers") end
        lines[#lines + 1] = line
        if #lines > 1 then
            local name, value = line:match("^([%w%-]+):%s*(.-)%s*$")
            if not name then return reject(400, "Invalid request header") end
            name = name:lower()
            if name == "transfer-encoding" then
                return reject(400, "Transfer encoding is not supported")
            elseif name == "content-length" then
                if content_length or not value:match("^%d+$") then
                    return reject(400, "Invalid Content-Length")
                end
                content_length = tonumber(value)
                if not content_length or content_length > 4096 then
                    return reject(413, "Request body too large")
                end
            end
        end
    end

    if not content_length then return reject(400, "Content-Length required") end
    local body = ""
    if content_length > 0 then body = receive(content_length) end
    if not body then client:close(); return end
    local request = table.concat(lines, "\r\n") .. "\r\n\r\n" .. body
    client:settimeout(0.5, "t")
    return server.receiveCallback(request, client)
end

return HTTPServer
