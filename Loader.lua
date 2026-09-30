local ROOT = ".../"

local Main = loadfile(ROOT .. "Main.lua")
if Main then
    local ok, err = pcall(Main)
    if not ok then warn("[Combat] Main.lua error: " .. tostring(err)) end
else
    warn("[Combat] failed to load Main.lua")
end
