-- Run from the repository root: lua tests/httpserver_spec.lua
local now = 0
package.loaded.socket = { gettime = function() return now end }
package.loaded["ui/message/simpletcpserver"] = { new = function(_, options) return options end }
local HTTPServer = dofile("remote_turner.koplugin/httpserver.lua")

local function run(request, delay)
    now = 0
    local client = { closed = false, offset = 1 }
    client.settimeout = function() end
    function client:close() self.closed = true end
    function client:receive(count)
        now = now + (delay or 0)
        if self.offset + count - 1 > #request then return nil end
        local value = request:sub(self.offset, self.offset + count - 1)
        self.offset = self.offset + count
        return value
    end
    local result = {}
    local server = HTTPServer:new {
        server = { accept = function() return client end },
        receiveCallback = function(data) result.request = data; client:close() end,
        rejectCallback = function(_, status) result.status = status; client:close() end,
    }
    server:waitEvent()
    assert(client.closed, "Every accepted connection must close")
    return result
end

local valid = "POST /v1/ping HTTP/1.1\r\ncOnTeNt-LeNgTh: 2\r\n\r\n{}"
assert(run(valid).request == valid, "Header names must be case insensitive")
for _, headers in ipairs({
    "Content-Length: 2\r\nContent-Length: 2", "Content-Length: -1",
    "Content-Length: abc", "Transfer-Encoding: chunked", "Host: kindle",
}) do
    assert(run("POST /v1/ping HTTP/1.1\r\n" .. headers .. "\r\n\r\n{}").status == 400)
end
assert(run("POST /v1/ping HTTP/1.1\r\nContent-Length: 4097\r\n\r\n").status == 413)
assert(run("POST /v1/ping HTTP/1.1\r\nX: " .. string.rep("a", 2048) .. "\r\n\r\n").status == 413)
assert(run("POST /v1/ping HTTP/1.1\r\n" .. string.rep("X: a\r\n", 65) .. "\r\n").status == 413)
local large_headers = string.rep("X: " .. string.rep("a", 1000) .. "\r\n", 9)
assert(run("POST /v1/ping HTTP/1.1\r\n" .. large_headers .. "\r\n").status == 413)
assert(not run(valid:sub(1, -2)).request, "Truncated bodies must not dispatch")
assert(not run(valid, 0.1).request, "Slow headers must share one request deadline")
assert(run("POST /v1/ping HTTP/1.1\r\nContent-Length: 4096\r\n\r\n" .. string.rep("a", 4096)).request)
print("HTTP parser checks passed")
