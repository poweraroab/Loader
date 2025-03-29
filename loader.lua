-- config
local repoName = "executor-gui"
local repoOwner = "poweraroab"
-- variables
local http_request = (syn and syn.request) or (http and http.request) or request or http_request
local wrapperEnv = {}
local loadedImports = {}

-- functions
local function wrapFuncGlobal(func, customFenv)
    customFenv = customFenv or {}
    local fenvCache = getfenv()
    local fenv = setmetatable({}, {
        __index = function(_, index)
            return customFenv[index] or fenvCache[index]
        end,
        __newindex = function(_, index, value)
            customFenv[index] = value
        end
    })

    return setfenv(func, fenv)
end

local function fetchFile(path, branch)
    -- Directly use the specified URL for loader.lua
    local url = "https://raw.githubusercontent.com/poweraroab/Loader/refs/heads/main/loader.lua"
    
    local result = (
        if not wrapperEnv.DEV_MODE then
            http_request({
                Url = url,
                Method = "GET",
                Headers = {
                    ["Content-Type"] = "text/html; charset=utf-8",
                    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", -- Adding User-Agent header
                }
            })
        else {Success = true}
    )
    
    local srcFile = (if (result.Success) then result.Body else nil)

    if not result.Success then
        warn("Failed to fetch file from URL:", url)
    else
        print("✔️ Successfully fetched the file!")
    end
    
    return (result.Success), srcFile
end


local function import(path, branch)
    -- Directly fetch from the hardcoded path
    branch = branch or "main"
    local importName = branch .. "|" .. path

    if loadedImports[importName] then
        return loadedImports[importName]
    end

    local fetchSucc, srcFile = fetchFile(path, branch)
    if not fetchSucc then
        error("❌ Import failed for: " .. path)
    end

    local loadedFunc, loadError = loadstring(srcFile, string.format("@%s/%s", repoName, path))
    if not loadedFunc then
        error("❌ loadstring() failed: " .. tostring(loadError))
    end

    local wrappedFunc = wrapFuncGlobal(loadedFunc, wrapperEnv)
    loadedImports[importName] = wrappedFunc
    return wrappedFunc
end

-- main
do -- environment init
    wrapperEnv["USING_JALON_LOADER"] = true
    wrapperEnv["import"] = import
    wrapperEnv["fetchFile"] = fetchFile
    wrapperEnv["DEV_MODE"] = false
end

-- Import main.lua from the repository
return import("main/main.lua")(...)
