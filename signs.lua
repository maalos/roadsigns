--[[
    Author: maalos/regex
    Discord: maalos
    
    Images' source: https://en.wikipedia.org/wiki/Road_signs_in_the_United_States
]]

local signTypes = {
    {1899, "pole"},
    {1909, "square"},
    {1910, "circle"},
    {1912, "octagon"},
    {1913, "rhombus"},
    -- {1914, "triange"}, -- unused in american signs afaik
    {1923, "upsidedown-triangle"},
    {1924, "cross"},
}

local exceptions = {
    ["224"]   = 1909,
    ["5"]     = 1912,
    ["81"]    = 1912,
    ["82"]    = 1923,
    ["235"]   = 1909,
    ["236"]   = 1909,
    ["294"]   = 1910,
    ["369"]   = 1924,
    ["76"]    = 1909,
    ["logo"]  = 1909,
}

function getTrafficSignModelFromTexture(texture, signName)
    if exceptions[signName] then
        return exceptions[signName]
    end
    
    local pixels = dxGetTexturePixels(texture)
    local r1, g1, b1, a1 = dxGetPixelColor(pixels, 15, 15)
    local r2, g2, b2, a2 = dxGetPixelColor(pixels, 30, 30)
    local r3, g3, b3, a3 = dxGetPixelColor(pixels, 30, 150)
    
    if a1 == 0 then
        if a2 == 0 then
            return 1913 -- or 1914
        else
            return 1912
        end
    else
        if a3 == 0 then
            return 1923
        end
    end
    return 1909
end

function loadCustomModel(name, modelID)
    engineReplaceCOL(engineLoadCOL("models/sign.col"), modelID)
    engineImportTXD(engineLoadTXD("models/signs.txd"), modelID)
    engineReplaceModel(engineLoadDFF("models/" .. name .. ".dff"), modelID)
    engineSetModelLODDistance(modelID, 200)
end

function createTrafficSign(signName, x, y, z, r)
    if not fileExists("img/" .. signName .. ".png") then return false end

    local texture = dxCreateTexture("img/" .. signName .. ".png")
    
    local img = fileOpen("img/" .. signName .. ".png")
    local sizeX, sizeY = dxGetPixelsSize(fileRead(img, fileGetSize(img)))
    fileClose(img)

    local poleObj = createObject(1899, x, y, z, 0, 0, r)

    local r2 = 0
    if signName == "369" then -- railroad cross
        r2 = 90
    end
    local signObj = createObject(getTrafficSignModelFromTexture(texture, signName), x, y, z + 2.75, r2, 0, r)
    setElementDoubleSided(signObj, true)
    setObjectScale(signObj, sizeX/200, 1, sizeY/200)

    local shader = dxCreateShader("replace.fx")
    engineApplyShaderToWorldTexture(shader, "znak", signObj)
    dxSetShaderValue(shader, "gTexture", texture)

    return {poleObj, signObj}
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, sign in ipairs(signTypes) do
        loadCustomModel(sign[2], sign[1])
    end

    for _, sign in ipairs(signs) do
        createTrafficSign(sign[1], sign[2], sign[3], sign[4], sign[5])
    end
end)


-- [[ for development purposes only
local currentSignName = 81
local marker = createMarker(0, 0, 0, "cylinder", 1, 255, 255, 255, 150)
local sign = createTrafficSign(currentSignName, 0, 0, 0, 0)

addCommandHandler("setsign", function(_, signName)
    if not signName then return outputChatBox("Every sign has a name!") end
    if signName ~= "logo" then
        if tonumber(signName) < 1 or tonumber(signName) > 468 then
            return outputChatBox("Wrong sign name!")
        end
    end
    if isElement(sign[2]) then
        destroyElement(sign[1])
        local x, y, z = getElementPosition(sign[2])
        local rx, ry, rz = getElementRotation(sign[2])
        destroyElement(sign[2])
        sign = createTrafficSign(signName, x, y, z - 2.75, rz)
        currentSignName = signName
    else
        return outputChatBox("Sign not found!")
    end
end)

local signIndexViewEnabled = false
addCommandHandler("siv", function()
    signIndexViewEnabled = not signIndexViewEnabled
    outputChatBox("Toggled sign index view!")
end)

addCommandHandler("signs", function()
    outputChatBox("Written the signs table to your clipboard")
    str = "signs = {\n"
    for i, v in ipairs(signs) do
        str = str .. "    [" .. i .. "] = {\"" .. v[1] .. "\"," .. string.format("%.2f", v[2]) .. "," .. string.format("%.2f", v[3]) .. "," .. string.format("%.2f", v[4]) .. "," .. v[5] .. "}, -- " .. getZoneName(v[2], v[3], v[4]) .. "\n"
    end
    str = str .. "}\n"

    setClipboard(str)
end)

addEventHandler("onClientPreRender", root, function()
    if not sign[2] then return end
    local x, y, z = getElementPosition(sign[2])
    setElementPosition(marker, x, y, z - 2.75)
    setElementPosition(sign[1], x, y, z - 2.75)
    local rx, ry, rz = getElementRotation(sign[2])
    if getKeyState("q") then
        setElementRotation(sign[2], rx, ry, rz - 2)
    end
    if getKeyState("e") then
        setElementRotation(sign[2], rx, ry, rz + 2)
    end

    if signIndexViewEnabled then
        for i, v in ipairs(signs) do
            local px, py, pz = getElementPosition(localPlayer) 
            local distance = getDistanceBetweenPoints3D(v[2], v[3], v[4], px, py, pz) 
            if distance <= 10 then 
                local sx, sy = getScreenFromWorldPosition(v[2], v[3], v[4], 1) 
                if not sx then return end 
                local scale = 1/(0.3 * (distance / 10)) 
                dxDrawText("Sign index: " .. i .. "\nSign model: " .. v[1], sx, sy - 30, sx, sy - 30, 0xFFFF6900, math.min (0.4 * (50/distance), 4), "default-bold", "center", "bottom", false, false, false ) 
            end
        end
    end
end)

bindKey("enter", "down", function()
    local x, y, z = getElementPosition(sign[2])
    local rx, ry, rz = getElementRotation(sign[2])
    table.insert(signs, {currentSignName, x, y, z - 2.75, rz})
    createTrafficSign(currentSignName, x, y, z - 2.75, rz)
    outputChatBox("Added this position to the table!")
end)

function onMouseClick(button, state, absoluteX, absoluteY, worldX, worldY, worldZ, clickedElement)
    if button == "left" and state == "up" then
        local x, y, z = getElementPosition(localPlayer)
        if getDistanceBetweenPoints3D(x, y, z, worldX, worldY, worldZ) > 50 then return outputChatBox("You're too far from this position!", 255, 0, 0) end
        setElementPosition(sign[2], worldX, worldY, worldZ + 2.75)
    end
end
addEventHandler("onClientClick", root, onMouseClick)
-- ]]