-- [ ЗАГРУЗЧИК САТОШИ v1.3 - ОДИН СКРИПТ ] --

local secret_key = "zhjkbn"
local encrypted_linoria = ""

local function decrypt(data, key)
    local decrypted = ""
    local i = 1
    for part in string.gmatch(data, "[^%.]+") do
        local val = tonumber(part, 36)
        local xor_val = val - i
        local key_byte = string.byte(key, (i - 1) % #key + 1)
        local original_byte = bit32.bxor(xor_val, key_byte)
        if original_byte < 0 then original_byte = 0 end
        if original_byte > 255 then original_byte = original_byte % 256 end
        decrypted = decrypted .. string.char(original_byte)
        i = i + 1
    end
    return decrypted
end

local function runScript(encrypted_str)
    local success, result = pcall(decrypt, encrypted_str, secret_key)
    if success then
        local func, err = loadstring(result)
        if func then 
            func() 
        else 
            warn("Ошибка загрузки: " .. tostring(err)) 
        end
    else
        warn("Ошибка расшифровки: " .. tostring(result))
    end
end

-- Сразу запускаем скрипт
runScript(encrypted_linoria)
