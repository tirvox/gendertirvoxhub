-- [ ЗАГРУЗЧИК САТОШИ v1.3 - ОДИН СКРИПТ ] --

local secret_key = "zhjkbn"
local encrypted_linoria = "35.6.8.e.b.z.l.y.c.f.g.2a.16.n.m.u.2x.1k.x.1c.1b.1u.u.1e.2z.2x.t.1n.1f.1o.14.36.2u.2u.1f.1f.1e.30.1g.16.1r.1c.1m.1i.24.1y.1i.24.22.1l.1j.2b.1o.1i.1x.3i.1u.1q.22.3h.23.1r.2f.2l.26.2g.48.2b.2c.23.25.2b.29.2u.26.2t.2p.27.29.28.34.2j.4g.2f.34.2f.2j.4c.2m.2t.33.2w.30.3b.39.2v.2x.3k.2w.3b.3a.37.33.2x.3n.3t.53.32.3g.3b.58.4y.58.54.5i.5y"

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
