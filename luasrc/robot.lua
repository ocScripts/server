local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local computer = require("computer")
local crc32 = require("crc32")
local goSocket = require("gosocket")

local Config = {
    Host="172.0.0.1",
    Port=42069,
}

function main()
    local conn = goSocket.newSocket(Config.Host, Config.Port, false)

    conn.registerEventHandler("load", load)
    conn.registerEventHandler("newFile", newFile)
    conn.registerEventHandler("reboot", reboot)

    conn.open()
    while not conn.isReady() do
        os.sleep(0.1) ---Required
    end
    
    local registerData = {}

    registerData.Files = {}
    registerData.Type = component.isAvailable("robot") and "robot" or "computer"
    registerData.Components = {}

    ---Get hashes of all scripts

    for file in filesystem.list("/home/") do
        local fileName = file

        if string.sub(fileName, 1, #".") == "." then
            goto continue
        end

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

        ::continue::
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

function load(data)
    require(data.Module)
end

function newFile(data) --- err string
    print("Making new file")
    local fileName = data.Name
    local fileContent = data.Content

    local err = filesystem.remove("/home/" .. fileName)
    if err ~= true then
        return "CORE: Failed to delete file " + fileName
    end
    
	local f = io.open(fileName, "w")
    if f == nil then
        return "CORE: Failed to open file " + fileName
    end

    f:write(fileContent)

    f:close()
end

function reboot(data)
    computer.shutdown(true)
end

main()