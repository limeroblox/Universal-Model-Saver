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

-- Get saveinstance function - SIMPLIFIED
local function getSaveInstance()
    if saveinstance then return saveinstance end
    if syn and syn.saveinstance then return syn.saveinstance end
    if save_instance then return save_instance end
    
    -- Try to load Universal Syn SaveInstance
    local success, loaded = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true))()
    end)
    
    if success and type(loaded) == "function" then
        return loaded
    end
    
    return nil
end

-- FIXED: Save model function that saves ONLY the specified model
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

    -- Clone and prepare model (ensure everything is archivable)
    local clone = model:Clone()
    
    -- Set archivable property on everything
    clone.Archivable = true
    for _, desc in ipairs(clone:GetDescendants()) do
        pcall(function() 
            desc.Archivable = true 
        end)
    end

    -- Try different saveinstance methods to find what works
    local success = false
    local errMsg = ""
    
    -- Method 1: Try with Objects table (most reliable for saving single model)
    local ok1, err1 = pcall(function()
        saveFunc({
            Objects = {clone},
            FileName = filePath:match("([^/\\]+)$") or nightboundName .. ".rbxm"
        })
    end)
    
    if ok1 then
        success = true
    else
        -- Method 2: Try direct save (some saveinstance versions work this way)
        local ok2, err2 = pcall(function()
            -- Create a temporary folder with just the model
            local tempModel = Instance.new("Model")
            tempModel.Name = nightboundName
            clone.Parent = tempModel
            saveFunc(tempModel, filePath)
            tempModel:Destroy()
        end)
        
        if ok2 then
            success = true
        else
            -- Method 3: Try the simplest approach
            local ok3, err3 = pcall(function()
                saveFunc(clone, filePath)
            end)
            
            if ok3 then
                success = true
            else
                -- Method 4: Try Universal Syn SaveInstance format
                local ok4, err4 = pcall(function()
                    saveFunc({
                        Object = clone,
                        FileName = nightboundName .. ".rbxm",
                        Mode = "Model",
                        Decompile = false,
                        IgnoreNotArchivable = true,
                        ShowStatus = false,
                        Path = "NightboundExports"
                    })
                end)
                
                if ok4 then
                    success = true
                else
                    errMsg = "All save methods failed:\n1: " .. tostring(err1) .. 
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

    -- Wait for file to exist with timeout
    local fileExists = false
    local fileData = nil
    
    for i = 1, 20 do  -- 10 second timeout
        task.wait(0.5)
        if isfile(filePath) then
            fileData = readfile(filePath)
            if fileData and #fileData > 100 then  -- Ensure file has content
                fileExists = true
                break
            end
        end
    end

    if not fileExists then
        -- Try alternative path
        local altPath = "NightboundExports/" .. nightboundName .. ".rbxm"
        if isfile(altPath) then
            filePath = altPath
            fileData = readfile(filePath)
            if fileData and #fileData > 100 then
                fileExists = true
            end
        end
    end

    if not fileExists then
        return false, "File was not created or is empty. Check if saveinstance is working."
    end

    local processingTime = os.time() - startTime
    local fileSizeKB = math.floor(#fileData / 1024 * 100) / 100

    return true, filePath, fileSizeKB, processingTime
end

-- FIXED: Nightbound export with proper file path
local function exportNightbound(npcName, webhookMode)
    setStatus("Searching", "Looking for " .. npcName .. "...")
    
    -- Search for Nightbound NPC
    local npc = nil
    local npcFolder = workspace:FindFirstChild("NPCs")
    
    if npcFolder then
        -- Check both Hostile and Custom folders
        local hostileFolder = npcFolder:FindFirstChild("Hostile")
        local customFolder = npcFolder:FindFirstChild("Custom")
        
        if hostileFolder then
            npc = hostileFolder:FindFirstChild(npcName)
        end
        
        if not npc and customFolder then
            npc = customFolder:FindFirstChild(npcName)
        end
        
        -- If still not found, search entire NPCs folder
        if not npc then
            npc = npcFolder:FindFirstChild(npcName)
        end
    end
    
    -- Also check workspace directly (some NPCs might be spawned)
    if not npc then
        npc = workspace:FindFirstChild(npcName)
    end
    
    if not npc then
        return false, npcName .. " not found. Make sure the NPC is spawned in-game."
    end
    
    setStatus("Found", "Preparing " .. npcName .. " for export...")
    
    -- Create safe filename
    local safeName = npcName:gsub("%s+", "_")
    local fileName = safeName .. ".rbxm"
    local filePath = "NightboundExports/" .. fileName
    
    -- Try to save the model
    local success, result, fileSizeKB, processingTime = saveNightboundModel(npc, filePath, npcName)
    
    if not success then
        return false, "Save failed: " .. tostring(result)
    end
    
    -- Verify the file was created
    task.wait(1)  -- Extra wait to ensure file is written
    
    if not isfile(filePath) then
        -- Try without the folder prefix
        local altPath = fileName
        if isfile(altPath) then
            filePath = altPath
        else
            return false, "File was not created at: " .. filePath
        end
    end
    
    local fileData = readfile(filePath)
    if not fileData or #fileData < 100 then
        return false, "File created but is too small or empty"
    end
    
    -- Handle webhook if enabled
    if webhookMode ~= "Disabled" then
        local data = {
            fileName = fileName,
            fileSizeKB = fileSizeKB,
            fileExtension = "rbxm",
            nightboundName = npcName,
            exportMode = "Nightbound Export",
            processingTime = processingTime,
            executor = getExecutorName()
        }
        
        if webhookMode == "Auto Upload" then
            local uploadSuccess = sendWebhookWithFile(filePath, data)
            if not uploadSuccess then
                sendWebhookNotification(data)
            end
        else
            sendWebhookNotification(data)
        end
    end
    
    return true, "✓ Saved " .. npcName .. "\nLocation: " .. filePath .. "\nSize: " .. fileSizeKB .. " KB", fileSizeKB
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
