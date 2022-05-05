local component = require("component")
local json = require("json-api")
local thread = require("thread")
local event = require("event")
local internet = require("internet")
local base64 = require("base64")

local goSocket = {_version="v0.0.1"}

if not component.isAvailable("internet") then
    io.stderr:write("goSockets require a internet card to run!\n")
end

goSocket.newSocket = function(host, port, debug)
    checkArg(1, host, "string")
    checkArg(2, port, "number")

    local self = {}
    self.eventHandlers = {}
    self.connected=false
    self.debug=false
    self.thred=nil
    self.uuid=""
    self.ready=false
    if debug ~= nil then
        self.debug=debug
    end

    self.isReady = function()
        return self.ready
    end

    self.registerEventHandler = function(name, handler)
        checkArg(1, name, "string")
        checkArg(2, handler, "function")
        self.eventHandlers[name]=handler
    end

    self.registerEventHandler("uuid", function(data)
        self.uuid = data.UUID
        self.ready = true
        
        if self.debug then
            print("INFO: Got UUID \""..uuid.."\".")
        end
    end)

    self.sendEvent = function(name, data)
        checkArg(1, name, "string")
        checkArg(2, data, "table")

        local event = {}
        event.Name = name
        event.Data = base64.encode(json.encode(data))
        local msg = json.encode(event).."\r\n"

        if self.debug then
            print("INFO: Sending message \""..msg.."\".")
        end

        self.conn:write(msg)
    end

    self.readSocket = function()
        if not self.conn then
            self.connected=false
            event.cancel(self.timer)
        end

        local message = self.conn:read()
        if self.debug then
            print("INFO: Recived message \""..message.."\".")
        end

        local event = json.decode(message)
        if self.eventHandlers[event.Name] ~= nil then
            if self.debug then
                print("INFO: Triggerig event handler for \""..event.Name.."\".")
            end
            self.eventHandlers[event.Name](json.decode(base64.decode(event.Data)))
        end
    end

    self.open = function()
        if self.connected then
            return
        end

        self.conn, reason = internet.open(host, port)
        if not self.conn then
            io.stderr:write(reason .. "\n")
            return
        end

        self.conn:setTimeout(0.5)
        self.connected=true
        self.timer = event.timer(0.5, self.readSocket, math.huge)
    end

    self.close = function()
        self.conn:close()
        event.cancel(self.timer)
    end

    return self
end

return goSocket