-- Exercise the real protocol handler with KOReader's UI and crypto boundaries replaced.
local pending, events, shown = {}, {}, {}
local settings = { port = 9090, secret = "test-secret", autostart = true }
local function widget()
    return { new = function(_, value)
        value.onShowKeyboard = function() end
        return value
    end }
end
for _, name in ipairs({"confirmbox", "infomessage", "qrmessage", "inputdialog"}) do
    package.loaded["ui/widget/" .. name] = widget()
end
package.loaded["ui/widget/container/widgetcontainer"] = { extend = function(_, value) return value end }
package.loaded.device = { model = "Kindle", isKindle = function() return false end }
package.loaded["ui/event"] = { new = function(_, name, value) return { name = name, value = value } end }
package.loaded["ui/uimanager"] = {
    nextTick = function(_, callback) pending[#pending + 1] = callback end,
    broadcastEvent = function(_, event) events[#events + 1] = event end,
    show = function(_, value) shown[#shown + 1] = value end,
    close = function() end,
}
local function bitop(a, b, is_or)
    local result, place = 0, 1
    while a > 0 or b > 0 do
        local x, y = a % 2, b % 2
        if (is_or and x + y > 0) or (not is_or and x ~= y) then result = result + place end
        a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
    end
    return result
end
package.loaded.bit = {
    bxor = function(a, b) return bitop(a, b, false) end,
    bor = function(a, b) return bitop(a, b, true) end,
}
local request
package.loaded.json = { decode = function(body) assert(body == "fixture"); return request end }
package.loaded.logger = { info = function() end, err = function() end }
package.loaded.mime = { unb64 = function() return string.rep(string.char(11), 32) end }
local hashes = 0
package.loaded["ffi/sha2"] = { sha256 = function(data)
    hashes = hashes + 1
    if hashes % 2 == 1 then
        assert(data:sub(65) == "version=1\naction=next\nnonce=abcdefghijklmnop")
        return "1a3b1c9c830516252328073bcfd65e9a9df31b0c3c08c63ff675924c3fa5414c"
    end
    return "051508b7e3020e6da5fb094794ebf4e9b4f92b53cbcd80cc5495d218ae213523"
end }
package.loaded.socket = {}
package.loaded.util = {}
package.loaded.gettext = function(value) return value end
package.loaded["ffi/util"] = { template = function(value) return value end }
_G.G_reader_settings = { readSetting = function() return settings end, saveSetting = function() end }
local plugin = dofile("remote_turner.koplugin/main.lua")
plugin.nonce_order, plugin.nonce_set = {}, {}
local status
plugin.sendResponse = function(_, _, code) status = code end
local function send(value, path)
    request, status = value, nil
    plugin:onRequest("POST " .. (path or "/v1/action") .. " HTTP/1.1\r\n\r\nfixture", {})
    return status
end
local valid = {
    version = 1, action = "next", nonce = "abcdefghijklmnop",
    mac = "051508b7e3020e6da5fb094794ebf4e9b4f92b53cbcd80cc5495d218ae213523" }
assert(send(valid) == 200)
assert(#events == 0, "Actions must be scheduled after responding")
pending[1]()
assert(events[1].name == "GotoViewRel" and events[1].value == 1)
assert(send(valid) == 409, "Replays must not turn another page")
assert(#pending == 1)
assert(send(valid, "/v1/ping") == 400)
assert(send({ version = 1, action = "next", nonce = "bad\nnonce_string", mac = valid.mac }) == 400)
assert(send({ version = 1, action = "next", nonce = valid.nonce, mac = string.rep("0", 64) }) == 401)
for i = 1, 129 do assert(plugin:addNonce("nonce" .. i)) end
assert(plugin:addNonce(valid.nonce), "Replay memory must be bounded")
local menu = { updateItems = function() end }
plugin:setPort(menu)
local dialog = shown[#shown]
dialog.getInputValue = function() return "9091" end
dialog.buttons[1][2].callback()
assert(settings.port == 9091, "Numeric text must be converted before comparison")
dialog.getInputValue = function() return "9.5" end
dialog.buttons[1][2].callback()
assert(settings.port == 9091, "Fractional ports must be rejected")
print("Plugin protocol checks passed")
