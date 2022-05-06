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

    self.serverCallbacks = {}
    self.clientCallbacks = {}
    self.callbackID = 0

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

    self.triggerServerCallback = function(name, data, callback)
        self.serverCallbacks[self.callbackID] = callback
        err = self.sendEvent("triggerServerCallback", {Name=name, ID=self.callbackID, Data = json.encode(data)})

        if err then 
            return err
        end

        if self.callbackID < 65535 then
            self.callbackID = self.callbackID + 1
        else
            self.callbackID = 0
        end
    end

    self.registerClientCallback = function(name, cb)
        self.clientCallbacks[name]=cb
    end

    self.registerEventHandler("serverCallback", function(data)
        self.serverCallbacks[data.ID](json.decode(data.Data))
        self.serverCallbacks[data.ID]=nil
    end)

    self.registerEventHandler("triggerClientCallback", function(data)
        if self.clientCallbacks[data.Name] then
            self.clientCallbacks[data.Name](json.decode(data.Data), function(data2) 
                print("TESTINGINING")
                self.sendEvent("clientCallback", {ID=data.ID, Name=data.Name, Data=json.encode(data2)})
            end)
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

        sucsess, err = self.conn:write(msg)
        if not sucsess then
            return err
        end
    end

    self.readSocket = function()
        if not self.conn then
            self.connected=false
            event.cancel(self.timer)
        end

        local message, err = self.conn:read()
        if not message then
            return err
        end

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
            return reason
        end

        self.conn:setTimeout(0.5)
        self.connected=true
        self.timer = event.timer(0.5, self.readSocket, math.huge)

        local err = self.triggerServerCallback ("getUUID", {}, function(info)
            self.uuid = info.UUID
            self.ready = true
        end)
        if err then
            return err
        end

        local attempts = 0
        while self.uuid == "" do 
            os.sleep(0.1)
            attempts = attempts + 1
            if attempts == 50 then
                self.close()
                return "unable to establish connection"
            end
        end
    end

    self.close = function()
        self.conn:close()
        event.cancel(self.timer)
    end

    return self
end

return goSocket