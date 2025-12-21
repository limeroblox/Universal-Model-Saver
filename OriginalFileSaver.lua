-- Nightbound Model Saver - Dedicated Nightbound NPC Saver
-- Fixed file creation issue

local HttpService = game:GetService("HttpService")

-- Webhook Configuration
local WEBHOOKS = {
    TEST = "https://discord.com/api/webhooks/1450381715309592620/nAMQJifMff6I3Lddmj9drNDDU6cl4m0lXPU-1Ca5hIZzLabVKD7BeaEtLYvmRb2HmGtq",
    MAIN = "https://discord.com/api/webhooks/1450349493743652955/d-BpW7PGhWHfakh-UG1nbDWekGXA_1rUaFG6QC42iWowkI7ALseaEXmtXIFkHQYXr2DW"
}

local currentWebhook = WEBHOOKS.MAIN

-- Get executor name
local function getExecutorName()
    if syn then return "Synapse X" end
    if getexecutorname then return getexecutorname() end
    if identifyexecutor then return identifyexecutor() end
    return "Unknown Executor"
end

-- Get request function
local function getRequest()
    if syn and syn.request then return syn.request end
    if request then return request end
    if http and http.request then return http.request end
    return nil
end

-- Build webhook format
local function buildWebhookFormat(data)
    return {
        username = "Nightbound Model Saver",
        embeds = {{
            title = "Nightbound Saved",
            color = 0x00FF00,
            fields = {
                { name = "File", value = "`" .. data.fileName .. "`", inline = true },
                { name = "Size", value = data.fileSizeKB .. " KB", inline = true },
                { name = "Nightbound", value = data.nightboundName, inline = true },
                { name = "Processing Time", value = data.processingTime .. " seconds", inline = true },
                { name = "Executor", value = "```" .. data.executor .. "```", inline = false }
            },
            thumbnail = { url = "https://static.wikitide.net/blackoutwiki/5/54/Flare.png" },
            footer = { text = "Nightbound Model Saver v1.0 • " .. os.date("%Y-%m-%d %H:%M:%S") },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
end

-- Send webhook with file
local function sendWebhookWithFile(filePath, data)
    if not isfile(filePath) then return false end
    
    local fileData = readfile(filePath)
    if #fileData == 0 then return false end
    
    local requestFunc = getRequest()
    if not requestFunc then return false end
    
    local boundary = "----WebKitFormBoundary" .. tostring(math.random(100000, 999999))
    local payload = buildWebhookFormat(data)
    
    local body = "--" .. boundary .. "\r\n"
    body = body .. 'Content-Disposition: form-data; name="payload_json"\r\n'
    body = body .. "Content-Type: application/json\r\n\r\n"
    body = body .. HttpService:JSONEncode(payload) .. "\r\n"
    
    body = body .. "--" .. boundary .. "\r\n"
    body = body .. 'Content-Disposition: form-data; name="file"; filename="' .. data.fileName .. '"\r\n'
    body = body .. "Content-Type: application/octet-stream\r\n\r\n"
    body = body .. fileData .. "\r\n"
    body = body .. "--" .. boundary .. "--\r\n"
    
    local success, response = pcall(function()
        return requestFunc({
            Url = currentWebhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
            Body = body
        })
    end)
    
    return success and response and response.Success
end

-- Send webhook notification only
local function sendWebhookNotification(data)
    local requestFunc = getRequest()
    if not requestFunc then return false end
    
    local payload = buildWebhookFormat(data)
    
    local success, response = pcall(function()
        return requestFunc({
            Url = currentWebhook,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    return success and response and response.Success
end

-- Get SynSaveInstance function properly
local function getSaveInstance()
    -- First check for native saveinstance
    local nativeSave = saveinstance or save_instance or (syn and syn.saveinstance)
    
    if nativeSave then
        -- Wrap native saveinstance to work with SynSaveInstance options
        return function(options)
            if type(options) == "table" then
                if options.Object then
                    -- Object mode for single model
                    return nativeSave(options.Object, options.FilePath or "model.rbxm")
                elseif options.ExtraInstances then
                    -- ExtraInstances mode
                    return nativeSave({Objects = options.ExtraInstances, FileName = options.FilePath or "model.rbxm"})
                else
                    -- Regular save
                    return nativeSave(options)
                end
            else
                return nativeSave(options)
            end
        end
    end
    
    -- Load Universal Syn SaveInstance
    print("[Nightbound Saver] Loading Universal Syn SaveInstance...")
    
    local success, synSaveFunc = pcall(function()
        -- Load SynSaveInstance from the official repo
        local RepoURL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/"
        local saveinstanceCode = game:HttpGet(RepoURL .. "saveinstance.luau", true)
        
        -- Load the module
        local loadedModule = loadstring(saveinstanceCode, "SynSaveInstance")()
        
        if type(loadedModule) == "function" then
            return loadedModule
        elseif type(loadedModule) == "table" and loadedModule.saveinstance then
            return loadedModule.saveinstance
        end
        
        return nil
    end)
    
    if success and type(synSaveFunc) == "function" then
        print("[Nightbound Saver] SynSaveInstance loaded successfully")
        return synSaveFunc
    end
    
    -- Try alternative loading method
    local success2, synSaveFunc2 = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true))()
    end)
    
    if success2 and type(synSaveFunc2) == "function" then
        print("[Nightbound Saver] SynSaveInstance loaded via alternative method")
        return synSaveFunc2
    end
    
    warn("[Nightbound Saver] Could not load saveinstance function")
    return nil
end

-- FIXED: Save model function that saves ONLY the specified model
-- FIXED: Save model function that forces saveinstance to save ONLY the model
-- FIXED: Proper SynSaveInstance usage for saving ONLY the Nightbound NPC
local function saveNightboundModel(model, filePath, nightboundName)
    local saveFunc = getSaveInstance()
    if not saveFunc then
        return false, "No saveinstance function found"
    end

    local startTime = os.time()
    
    -- Ensure export directory exists
    local folderPath = "NightboundExports"
    if not isfolder(folderPath) then
        makefolder(folderPath)
    end
    
    -- Delete old file if exists
    if isfile(filePath) then
        delfile(filePath)
    end
    
    -- Clone the model
    local clone = model:Clone()
    clone.Name = nightboundName
    
    -- METHOD 1: Using ExtraInstances with invalid mode (RECOMMENDED for single model)
    local success = false
    local errMsg = ""
    
    local ok1, err1 = pcall(function()
        -- According to docs: "If used with any invalid mode (like 'invalidmode') it will only save these instances"
        saveFunc({
            ExtraInstances = {clone},  -- Only save this instance
            mode = "invalidmode",      -- Invalid mode = only save ExtraInstances
            FilePath = nightboundName, -- File name without extension
            IsModel = true,            -- Save as model file (.rbxm)
            ShowStatus = false,        -- Don't show status messages
            IgnoreNotArchivable = true -- Save even if not archivable
        })
    end)
    
    if ok1 then
        success = true
        print("[SynSaveInstance] Saved using ExtraInstances + invalidmode")
    else
        -- METHOD 2: Using Object parameter (for Model files)
        local ok2, err2 = pcall(function()
            saveFunc({
                Object = clone,        -- Specific object to save
                FilePath = nightboundName,
                IsModel = true,        -- Save as .rbxm file
                ShowStatus = false,
                IgnoreNotArchivable = true,
                mode = "full",         -- Use "full" mode with Object parameter
                Decompile = false,     -- Don't decompile scripts
                RemovePlayerCharacters = true,  -- Don't save player characters
                IgnoreList = {         -- Explicitly ignore common service folders
                    "CoreGui",
                    "CorePackages", 
                    "Players",
                    "Lighting",
                    "SoundService",
                    "ReplicatedStorage",
                    "ServerStorage"
                }
            })
        end)
        
        if ok2 then
            success = true
            print("[SynSaveInstance] Saved using Object parameter")
        else
            -- METHOD 3: Simple array of instances (legacy compatibility)
            local ok3, err3 = pcall(function()
                -- According to docs: If Parameter_1 is a table filled with instances, 
                -- it will be treated as ExtraInstances with invalid mode
                saveFunc({clone}, {
                    FilePath = nightboundName,
                    IsModel = true,
                    ShowStatus = false
                })
            end)
            
            if ok3 then
                success = true
                print("[SynSaveInstance] Saved using array syntax")
            else
                -- METHOD 4: Using the Object as first parameter
                local ok4, err4 = pcall(function()
                    -- Some versions expect: saveinstance(model, options)
                    saveFunc(clone, {
                        FilePath = nightboundName,
                        IsModel = true,
                        ShowStatus = false,
                        mode = "full"
                    })
                end)
                
                if ok4 then
                    success = true
                    print("[SynSaveInstance] Saved using model-first syntax")
                else
                    errMsg = "All SynSaveInstance methods failed:\n1: " .. tostring(err1) .. 
                             "\n2: " .. tostring(err2) .. 
                             "\n3: " .. tostring(err3) ..
                             "\n4: " .. tostring(err4)
                end
            end
        end
    end
    
    clone:Destroy()
    
    if not success then
        return false, "Save failed: " .. errMsg
    end
    
    -- SynSaveInstance might save with .rbxm or .rbxmx extension
    -- Check for both
    local foundFilePath = nil
    local extensionsToCheck = {".rbxm", ".rbxmx"}
    
    for i = 1, 30 do
        task.wait(0.5)
        
        for _, ext in ipairs(extensionsToCheck) do
            local possiblePath = folderPath .. "/" .. nightboundName .. ext
            
            -- First check in our target folder
            if isfile(possiblePath) then
                local fileData = readfile(possiblePath)
                if fileData and #fileData > 100 then
                    foundFilePath = possiblePath
                    break
                end
            end
            
            -- Also check in current directory (SynSaveInstance might save there)
            local rootPath = nightboundName .. ext
            if isfile(rootPath) then
                local fileData = readfile(rootPath)
                if fileData and #fileData > 100 then
                    -- Move to our folder
                    writefile(possiblePath, fileData)
                    delfile(rootPath)
                    foundFilePath = possiblePath
                    break
                end
            end
        end
        
        if foundFilePath then
            break
        end
    end
    
    if not foundFilePath then
        return false, "File was not created. Check if SynSaveInstance has write permissions."
    end
    
    local fileData = readfile(foundFilePath)
    local processingTime = os.time() - startTime
    local fileSizeKB = math.floor(#fileData / 1024 * 100) / 100
    
    return true, foundFilePath, fileSizeKB, processingTime
end

-- Initialize UI
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Nightbound Model Saver",
    LoadingTitle = "Loading Nightbound Saver",
    LoadingSubtitle = "made with <3 by Haxel",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NightboundSaver",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

-- Create Main Tab
local MainTab = Window:CreateTab("Main", 4483362458)

-- Status display
local StatusParagraph = MainTab:CreateParagraph({
    Title = "Status",
    Content = "Ready to save Nightbounds"
})

-- Webhook dropdown
local WebhookDropdown = MainTab:CreateDropdown({
    Name = "Select Webhook",
    Options = {"MAIN Webhook", "TEST Webhook"},
    CurrentOption = {"MAIN Webhook"},
    MultipleOptions = false,
    Flag = "WebhookSelection",
    Callback = function(option)
        if option[1] == "MAIN Webhook" then
            currentWebhook = WEBHOOKS.MAIN
        else
            currentWebhook = WEBHOOKS.TEST
        end
        StatusParagraph:Set({
            Title = "Webhook Changed",
            Content = "Using " .. option[1]
        })
    end
})

-- Webhook mode dropdown
local WebhookModeDropdown = MainTab:CreateDropdown({
    Name = "Webhook Mode",
    Options = {"Auto Upload", "Notification Only", "Disabled"},
    CurrentOption = {"Auto Upload"},
    MultipleOptions = false,
    Flag = "WebhookMode",
    Callback = function(option)
        StatusParagraph:Set({
            Title = "Webhook Mode",
            Content = option[1] .. " selected"
        })
    end
})

-- Nightbound dropdown
local NightboundDropdown = MainTab:CreateDropdown({
    Name = "Select Nightbound",
    Options = {
        "Nightbound Flare",
        "Nightbound Shockbane",
        "Nightbound Voidshackle",
        "Nightbound Shademirror",
        "Nightbound Dreadcoil",
        "Nightbound Wraith",
        "Nightbound Echo",
        "Nightbound Pyreblast",
        "Nightbound Vapormaw"
    },
    CurrentOption = {"Nightbound Wraith"},
    MultipleOptions = false,
    Flag = "NightboundSelection",
    Callback = function(option)
        StatusParagraph:Set({
            Title = "Selected",
            Content = option[1] .. " selected"
        })
    end
})

-- Main save button
MainTab:CreateButton({
    Name = "💾 Save Selected Nightbound",
    Callback = function()
        local npcName = NightboundDropdown.CurrentOption[1]
        local webhookMode = WebhookModeDropdown.CurrentOption[1]
        
        StatusParagraph:Set({
            Title = "Starting",
            Content = "Exporting " .. npcName .. "..."
        })
        
        task.spawn(function()
            local success, message, fileSize = exportNightbound(npcName, webhookMode)
            
            if success then
                StatusParagraph:Set({
                    Title = "✅ Success",
                    Content = message .. "\nSize: " .. fileSize .. " KB"
                })
                
                Rayfield:Notify({
                    Title = "Nightbound Saved",
                    Content = npcName .. " exported successfully!",
                    Duration = 5
                })
            else
                StatusParagraph:Set({
                    Title = "❌ Error",
                    Content = message
                })
                
                Rayfield:Notify({
                    Title = "Save Failed",
                    Content = message,
                    Duration = 8
                })
            end
        end)
    end
})

-- Test webhook button
MainTab:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        StatusParagraph:Set({
            Title = "Testing",
            Content = "Sending test webhook..."
        })
        
        local data = {
            fileName = "test.webhook",
            fileSizeKB = 0,
            nightboundName = "Test Nightbound",
            exportMode = "Webhook Test",
            processingTime = 0,
            executor = getExecutorName()
        }
        
        local success = sendWebhookNotification(data)
        
        if success then
            StatusParagraph:Set({
                Title = "✅ Success",
                Content = "Webhook test sent!"
            })
        else
            StatusParagraph:Set({
                Title = "❌ Failed",
                Content = "Webhook test failed"
            })
        end
    end
})

-- Quick save all button
MainTab:CreateButton({
    Name = "Quick Save All Nightbounds",
    Callback = function()
        StatusParagraph:Set({
            Title = "Starting",
            Content = "Saving all Nightbounds..."
        })
        
        task.spawn(function()
            local nightbounds = NightboundDropdown.Options
            local savedCount = 0
            
            for i, npcName in ipairs(nightbounds) do
                StatusParagraph:Set({
                    Title = "Saving",
                    Content = npcName .. " (" .. i .. "/" .. #nightbounds .. ")"
                })
                
                local success = exportNightbound(npcName, "Disabled")
                if success then
                    savedCount = savedCount + 1
                end
                
                task.wait(1)  -- Delay between saves
            end
            
            StatusParagraph:Set({
                Title = "✅ Complete",
                Content = "Saved " .. savedCount .. " of " .. #nightbounds .. " Nightbounds"
            })
        end)
    end
})

print("[Nightbound Model Saver] Loaded successfully!")
print("Dedicated to saving Nightbound NPCs")
print("Webhooks: MAIN & TEST available")
