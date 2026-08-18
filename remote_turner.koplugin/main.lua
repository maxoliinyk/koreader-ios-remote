local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local QRMessage = require("ui/widget/qrmessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local bit = require("bit")
local json = require("json")
local logger = require("logger")
local mime = require("mime")
local sha = require("ffi/sha2")
local socket = require("socket")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

local RemoteTurner = WidgetContainer:extend {
    name = "remote_turner",
    is_doc_only = false,
    settings_key = "remote_turner_http_v1",
}

local settings = G_reader_settings:readSetting(RemoteTurner.settings_key, {
    port = 9090,
    autostart = true,
})

local RESPONSE_REASON = {
    [200] = "OK", [400] = "Bad Request", [401] = "Unauthorized",
    [404] = "Not Found", [405] = "Method Not Allowed", [409] = "Conflict",
    [413] = "Content Too Large", [423] = "Locked", [500] = "Internal Server Error",
}

local function persist_settings()
    G_reader_settings:saveSetting(RemoteTurner.settings_key, settings)
end

local function hex_to_binary(value)
    return value:gsub("..", function(pair) return string.char(tonumber(pair, 16)) end)
end

local function hmac_sha256(key, message)
    if #key > 64 then key = hex_to_binary(sha.sha256(key)) end
    key = key .. string.rep("\0", 64 - #key)
    local inner, outer = {}, {}
    for index = 1, 64 do
        local byte = key:byte(index)
        inner[index] = string.char(bit.bxor(byte, 0x36))
        outer[index] = string.char(bit.bxor(byte, 0x5c))
    end
    local inner_hash = sha.sha256(table.concat(inner) .. message)
    return sha.sha256(table.concat(outer) .. hex_to_binary(inner_hash))
end

local function constant_time_equal(left, right)
    if type(left) ~= "string" or type(right) ~= "string" or #left ~= #right then return false end
    local difference = 0
    for index = 1, #left do
        difference = bit.bor(difference, bit.bxor(left:byte(index), right:byte(index)))
    end
    return difference == 0
end

local function random_bytes(count)
    local file = io.open("/dev/urandom", "rb")
    if not file then return nil end
    local value = file:read(count)
    file:close()
    if not value or #value ~= count then return nil end
    return value
end

local function base64url(value)
    return (mime.b64(value):gsub("%s", ""):gsub("+", "-"):gsub("/", "_"):gsub("=", ""))
end

local function decode_base64url(value)
    local base64 = value:gsub("-", "+"):gsub("_", "/")
    local remainder = #base64 % 4
    if remainder > 0 then base64 = base64 .. string.rep("=", 4 - remainder) end
    return mime.unb64(base64)
end

local function ensure_secret()
    if settings.secret and #decode_base64url(settings.secret) == 32 then return true end
    local bytes = random_bytes(32)
    if not bytes then return false end
    settings.secret = base64url(bytes)
    persist_settings()
    return true
end

local function local_address()
    local udp = socket.udp()
    if not udp then return nil end
    udp:settimeout(0)
    udp:setpeername("8.8.8.8", 53)
    local host = udp:getsockname()
    udp:close()
    if host == "0.0.0.0" then return nil end
    return host
end

local function pairing_uri()
    local host = local_address()
    if not host or not ensure_secret() then return nil end
    local name = Device.model or "Kindle"
    return string.format(
        "koreaderturner://pair?v=1&host=%s&port=%d&name=%s&secret=%s",
        util.urlEncode(host), settings.port, util.urlEncode(tostring(name)), settings.secret
    )
end

function RemoteTurner:init()
    ensure_secret()
    self.nonce_order = {}
    self.nonce_set = {}
    self.ui.menu:registerToMainMenu(self)
    if settings.autostart then UIManager:nextTick(function() self:start() end) end
end

function RemoteTurner:isRunning()
    return self.http_socket ~= nil
end

function RemoteTurner:addNonce(nonce)
    if self.nonce_set[nonce] then return false end
    self.nonce_set[nonce] = true
    table.insert(self.nonce_order, nonce)
    if #self.nonce_order > 128 then self.nonce_set[table.remove(self.nonce_order, 1)] = nil end
    return true
end

function RemoteTurner:openFirewall()
    if not Device:isKindle() then return end
    os.execute(string.format(
        "iptables -A INPUT -p tcp --dport %d -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT", settings.port
    ))
    os.execute(string.format(
        "iptables -A OUTPUT -p tcp --sport %d -m conntrack --ctstate ESTABLISHED -j ACCEPT", settings.port
    ))
    self.firewall_open = true
end

function RemoteTurner:closeFirewall()
    if not Device:isKindle() or not self.firewall_open then return end
    os.execute(string.format(
        "iptables -D INPUT -p tcp --dport %d -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT", settings.port
    ))
    os.execute(string.format(
        "iptables -D OUTPUT -p tcp --sport %d -m conntrack --ctstate ESTABLISHED -j ACCEPT", settings.port
    ))
    self.firewall_open = nil
end

function RemoteTurner:start(show_error)
    if self:isRunning() then return true end
    local ServerClass = require("httpserver")
    self.http_socket = ServerClass:new {
        host = "*",
        port = settings.port,
        receiveCallback = function(data, client) return self:onRequest(data, client) end,
    }
    local ok, err = self.http_socket:start()
    if not ok then
        self.http_socket = nil
        self:closeFirewall()
        logger.err("RemoteTurner: failed to start listener:", err)
        if show_error then
            UIManager:show(InfoMessage:new {
                text = T(_("Could not start Remote Turner on port %1. The port may already be in use."), settings.port),
            })
        end
        return false
    end
    self:openFirewall()
    self.http_messagequeue = UIManager:insertZMQ(self.http_socket)
    logger.info("RemoteTurner: listener started on port", settings.port)
    return true
end

function RemoteTurner:stop()
    self:closeFirewall()
    if self.http_socket then self.http_socket:stop(); self.http_socket = nil end
    if self.http_messagequeue then
        UIManager:removeZMQ(self.http_messagequeue)
        self.http_messagequeue = nil
    end
    logger.info("RemoteTurner: listener stopped")
end

function RemoteTurner:sendResponse(client, status, body)
    local encoded = json.encode(body)
    local response = table.concat({
        string.format("HTTP/1.0 %d %s", status, RESPONSE_REASON[status] or "Error"),
        "Content-Type: application/json; charset=utf-8",
        "Content-Length: " .. #encoded,
        "Cache-Control: no-store",
        "Connection: close",
        "",
        encoded,
    }, "\r\n")
    if self.http_socket then self.http_socket:send(response, client) end
    return Event:new("InputEvent")
end

function RemoteTurner:reject(client, status, message)
    return self:sendResponse(client, status, { ok = false, message = message })
end

function RemoteTurner:onRequest(data, client)
    local method, path = data:match("^(%u+) ([^ ]+) HTTP/%d%.%d\r?\n")
    if method ~= "POST" then return self:reject(client, 405, "POST required") end
    if path ~= "/v1/action" and path ~= "/v1/ping" then
        return self:reject(client, 404, "Unknown route")
    end

    local body = data:match("\r?\n\r?\n(.*)$")
    if not body or #body > 4096 then
        return self:reject(client, body and 413 or 400, "Invalid request body")
    end
    local ok, request = pcall(json.decode, body)
    if not ok or type(request) ~= "table" then return self:reject(client, 400, "Invalid JSON") end
    if request.version ~= 1 or type(request.action) ~= "string"
            or type(request.nonce) ~= "string" or type(request.mac) ~= "string"
            or #request.nonce < 16 or #request.nonce > 128 or #request.mac ~= 64 then
        return self:reject(client, 400, "Invalid protocol fields")
    end

    local expected_action = path == "/v1/ping" and "ping" or request.action
    if expected_action ~= request.action then return self:reject(client, 400, "Action does not match route") end
    if path == "/v1/action" and request.action ~= "next"
            and request.action ~= "previous" and request.action ~= "sleep" then
        return self:reject(client, 400, "Unknown action")
    end

    local canonical = string.format("version=%d\naction=%s\nnonce=%s", request.version, request.action, request.nonce)
    local expected_mac = hmac_sha256(decode_base64url(settings.secret or ""), canonical)
    if not constant_time_equal(expected_mac, request.mac:lower()) then
        return self:reject(client, 401, "Authentication failed")
    end
    if not self:addNonce(request.nonce) then return self:reject(client, 409, "Nonce already used") end

    local response = self:sendResponse(client, 200, { ok = true, message = "accepted" })
    if request.action ~= "ping" then
        UIManager:nextTick(function()
            if request.action == "next" then
                UIManager:broadcastEvent(Event:new("GotoViewRel", 1))
            elseif request.action == "previous" then
                UIManager:broadcastEvent(Event:new("GotoViewRel", -1))
            elseif request.action == "sleep" then
                UIManager:broadcastEvent(Event:new("RequestSuspend"))
            end
        end)
    end
    return response
end

function RemoteTurner:showPairingCode()
    local uri = pairing_uri()
    if not uri then
        UIManager:show(InfoMessage:new { text = _("Could not determine this Kindle's Wi-Fi address.") })
        return
    end
    UIManager:show(QRMessage:new {
        text = uri,
        width = Device.screen:getWidth(),
        height = Device.screen:getHeight(),
    })
end

function RemoteTurner:showManualDetails()
    local host = local_address() or _("Unavailable")
    ensure_secret()
    UIManager:show(InfoMessage:new {
        text = T(_("Name: %1\nAddress: %2\nPort: %3\nProtocol: 1\nSecret:\n%4"),
            tostring(Device.model or "Kindle"), host, settings.port, settings.secret),
    })
end

function RemoteTurner:regenerateSecret()
    UIManager:show(ConfirmBox:new {
        text = _("Generate a new pairing secret? Existing phones and watches will stop working."),
        ok_callback = function()
            local bytes = random_bytes(32)
            if not bytes then return end
            settings.secret = base64url(bytes)
            self.nonce_order, self.nonce_set = {}, {}
            persist_settings()
            self:showPairingCode()
        end,
    })
end

function RemoteTurner:setPort(touchmenu_instance)
    local InputDialog = require("ui/widget/inputdialog")
    local dialog
    dialog = InputDialog:new {
        title = _("Listener port"),
        input = tostring(settings.port),
        input_type = "number",
        input_hint = _("Port number (default 9090)"),
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            {
                text = _("Save"),
                callback = function()
                    local port = dialog:getInputValue()
                    if port and port >= 1 and port <= 65535 then
                        local was_running = self:isRunning()
                        if was_running then self:stop() end
                        settings.port = port
                        persist_settings()
                        if was_running then self:start(true) end
                    end
                    UIManager:close(dialog)
                    touchmenu_instance:updateItems()
                end,
            },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function RemoteTurner:addToMainMenu(menu_items)
    menu_items.remote_turner = {
        text = _("Remote Turner"),
        sub_item_table = {
            { text = _("Show pairing QR code"), callback = function() self:showPairingCode() end },
            { text = _("Show manual pairing details"), callback = function() self:showManualDetails() end },
            {
                text_func = function()
                    return self:isRunning() and T(_("Listening on port %1"), settings.port) or _("Listener stopped")
                end,
                callback = function()
                    if self:isRunning() then settings.autostart = nil; self:stop()
                    else settings.autostart = true; self:start(true) end
                    persist_settings()
                end,
            },
            {
                text_func = function() return T(_("Port: %1"), settings.port) end,
                callback = function(touchmenu_instance) self:setPort(touchmenu_instance) end,
            },
            { text = _("Generate new pairing secret"), callback = function() self:regenerateSecret() end },
        },
    }
end

function RemoteTurner:onEnterStandby() if self:isRunning() then self:stop() end end
function RemoteTurner:onSuspend() if self:isRunning() then self:stop() end end
function RemoteTurner:onExit() if self:isRunning() then self:stop() end end
function RemoteTurner:onCloseWidget() if self:isRunning() then self:stop() end end
function RemoteTurner:onLeaveStandby() if settings.autostart and not self:isRunning() then self:start() end end
function RemoteTurner:onResume() if settings.autostart and not self:isRunning() then self:start() end end

return RemoteTurner
