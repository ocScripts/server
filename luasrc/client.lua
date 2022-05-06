local component = require("component")
local computer = require("computer")
local event = require("event")
local filesystem = require("filesystem")

local crc32 = require("crc32")
local goSocket = require("gosocket")
local json = require("json-api")

---Default configuration table
local Config = {
    Host="127.0.0.1",
    Port=56552,
    Type="robot",
}

function main()
    local f = io.open("config.json", "r")
    if f == nil then
        local b = json.encode(Config)
        if b == nil then
            return "CORE: Failed to marshal configuration " + Config
        end

        local f = io.open("config.json", "w")
        if f == nil then
            return "CORE: Failed to open file " + fileName
        end

        f:write(b)

        f:close()
    else
        Config = json.decode(f:read("*a"))
    end


    ::RetryConnect::
    local conn = goSocket.newSocket(Config.Host, Config.Port, true)
    ---conn.registerEventHandler("getDisplayResolution", getDisplayResolution)
    conn.registerEventHandler("load", load)
    conn.registerClientCallback("newFile", newFile)
    conn.registerEventHandler("reboot", reboot)

    local err = conn.open()
    if err ~= nil then
        print("Error while connecting '"..err.."'. Retrying...")
        goto RetryConnect
    end
    
    local registerData = {}

    registerData.Files = {}
    registerData.Type = Config.Type
    registerData.Components = {}

    ---Get hashes of all scripts

    for file in filesystem.list("/home/") do
        local fileName = file

        local f = io.open("/home/"..fileName, "r")
        if f == nil then
            error("CORE: Failed to open file " .. fileName)
        end

        local fileBytes = f:read("*a")
        if fileBytes == nil then
            error("CORE: Got nil file when reading " .. fileName)
        end

        local hash = crc32.hash(fileBytes)
        if hash == nil then
            error("CORE: crc32 returned nil hash!")
        end
        
        registerData.Files[fileName] = hash

        f:close()
    end

    ---Populate our component list

    for _,name in component.list() do
        table.insert(registerData.Components, name)
    end

    conn.sendEvent("register", registerData)

    event.pull("interrupted")

    conn.close()

    print("Exiting")
end

---Gets the current display resolution
---function getDisplayResolution()
---    return gpu.getViewport() --TODO:
---end

function load(data)
    require(data.Module)
end

function newFile(data, cb) --- err string
    print("Making new file")
    local fileName = data.Name
    local fileContent = data.Content
    print(fileName)
    local err = filesystem.remove("/home/" .. fileName)
    if err ~= true then
        cb({Err="CORE: Failed to delete file " + fileName})
    end
    
	local f = io.open(fileName, "w")
    if f == nil then
        cb({Err="CORE: Failed to open file " + fileName})
    end
    f:write(fileContent)

    f:close()
    cb({Err=""})
end

function reboot(data)
    computer.shutdown(true)
end

main()