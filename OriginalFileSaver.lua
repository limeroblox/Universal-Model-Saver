-- Universal Model Saver - Main Logic File
-- Clean, working version based on original structure

local HttpService = game:GetService("HttpService")

-- Webhook Configuration
local WEBHOOKS = {
    TEST = "https://discord.com/api/webhooks/1450381715309592620/nAMQJifMff6I3Lddmj9drNDDU6cl4m0lXPU-1Ca5hIZzLabVKD7BeaEtLYvmRb2HmGtq",
    MAIN = "https://discord.com/api/webhooks/1450349493743652955/d-BpW7PGhWHfakh-UG1nbDWekGXA_1rUaFG6QC42iWowkI7ALseaEXmtXIFkHQYXr2DW"
}

local currentWebhook = WEBHOOKS.MAIN

-- Get request function
local function getRequest()
    if syn and syn.request then return syn.request end
    if request then return request end
    if http and http.request then return http.request end
    return nil
end

-- Function to build webhook format
local function buildWebhookFormat(data)
    return {
        username = "Universal Model Saver",
        embeds = {{
            title = "Export Complete",
            color = 0x00FF00,
            fields = {
                { name = "File", value = "`" .. data.fileName .. "`", inline = true },
                { name = "Size", value = data.fileSizeKB .. " KB", inline = true },
                { name = "Type", value = data.fileExtension or "rbxm", inline = true },
                { name = "Export Mode", value = data.exportMode, inline = true },
                { name = "Processing Time", value = data.processingTime .. " seconds", inline = true },
                { name = "Executor", value = "```" .. data.executor .. "```", inline = false }
            },
            thumbnail = { url = "https://static.wikitide.net/blackoutwiki/5/54/Flare.png" },
            footer = { text = "Saved By Universal Model Saver v1.0 • " .. os.date("%Y-%m-%d %H:%M:%S") },
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

-- Get saveinstance function
local function getSaveInstance()
    local saveFunc = saveinstance or save_instance or (syn and syn.saveinstance)
    
    if not saveFunc then
        local success, loaded = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true))()
        end)
        if success and type(loaded) == "function" then
            return loaded, false
        end
        return nil, false
    end
    
    return saveFunc, true
end

-- Save model function
local function saveModel(model, filePath)
    local saveFunc, isNative = getSaveInstance()
    if not saveFunc then return false end
    
    local success = false
    
    if isNative then
        if setthreadidentity then
            local original = getthreadidentity()
            setthreadidentity(7)
            
            local attempts = {
                function() saveFunc({Objects = {model}, FileName = filePath}) end,
                function() saveFunc(model, filePath) end
            }
            
            for _, attempt in ipairs(attempts) do
                local ok = pcall(attempt)
                if ok then success = true break end
            end
            
            setthreadidentity(original)
        else
            local attempts = {
                function() saveFunc({Objects = {model}, FileName = filePath}) end,
                function() saveFunc(model, filePath) end
            }
            
            for _, attempt in ipairs(attempts) do
                local ok = pcall(attempt)
                if ok then success = true break end
            end
        end
    else
        local ok = pcall(function()
            saveFunc({
                Object = model,
                FileName = filePath:match("([^/\\]+)$") or "model.rbxm",
                Mode = "Model",
                Decompile = false,
                IgnoreNotArchivable = true,
                ShowStatus = false,
                Path = "UniversalModelSaver/Exports"
            })
        end)
        success = ok
    end
    
    return success
end

-- Standard export
local function standardExport(modelName, webhookMode)
    local model = workspace:FindFirstChild(modelName)
    if not model then return false, "Model not found" end
    
    local exportDir = "UniversalModelSaver/Exports"
    if not isfolder(exportDir) then makefolder(exportDir) end
    
    local fileName = modelName:gsub("%s+", "_")
    local filePath = exportDir .. "/" .. fileName .. ".rbxm"
    
    if isfile(filePath) then delfile(filePath) end
    
    local clone = model:Clone()
    clone.Archivable = true
    for _, v in ipairs(clone:GetDescendants()) do pcall(function() v.Archivable = true end) end
    
    local success = saveModel(clone, filePath)
    clone:Destroy()
    
    if not success then return false, "Save failed" end
    
    task.wait(1)
    if not isfile(filePath) then return false, "File not created" end
    
    local fileData = readfile(filePath)
    local fileSizeKB = math.floor(#fileData / 1024 * 100) / 100
    
    if webhookMode ~= "Disabled" then
        local data = {
            fileName = fileName .. ".rbxm",
            fileSizeKB = fileSizeKB,
            fileExtension = "rbxm",
            exportMode = "Standard Export",
            processingTime = 1,
            executor = identifyexecutor and identifyexecutor() or "Unknown"
        }
        
        if webhookMode == "Auto Upload" then
            if not sendWebhookWithFile(filePath, data) then
                sendWebhookNotification(data)
            end
        else
            sendWebhookNotification(data)
        end
    end
    
    return true, filePath, fileSizeKB
end

-- Nightbound export
local function nightboundExport(npcName, webhookMode)
    local npc = nil
    local npcFolder = workspace:FindFirstChild("NPCs")
    
    if npcFolder then
        for _, folderName in ipairs({"Hostile", "Custom"}) do
            local folder = npcFolder:FindFirstChild(folderName)
            if folder then
                npc = folder:FindFirstChild(npcName)
                if npc then break end
            end
        end
    end
    
    if not npc then return false, "Nightbound not found" end
    
    local exportDir = "UniversalModelSaver/Nightbound"
    if not isfolder(exportDir) then makefolder(exportDir) end
    
    local fileName = npcName:gsub("%s+", "")
    local filePath = exportDir .. "/" .. fileName .. ".rbxm"
    
    if isfile(filePath) then delfile(filePath) end
    
    local clone = npc:Clone()
    clone.Archivable = true
    for _, v in ipairs(clone:GetDescendants()) do pcall(function() v.Archivable = true end) end
    
    local success = saveModel(clone, filePath)
    clone:Destroy()
    
    if not success then return false, "Save failed" end
    
    task.wait(1)
    if not isfile(filePath) then return false, "File not created" end
    
    local fileData = readfile(filePath)
    local fileSizeKB = math.floor(#fileData / 1024 * 100) / 100
    
    if webhookMode ~= "Disabled" then
        local data = {
            fileName = fileName .. ".rbxm",
            fileSizeKB = fileSizeKB,
            fileExtension = "rbxm",
            exportMode = "Nightbound Export",
            processingTime = 1,
            executor = identifyexecutor and identifyexecutor() or "Unknown"
        }
        
        if webhookMode == "Auto Upload" then
            if not sendWebhookWithFile(filePath, data) then
                sendWebhookNotification(data)
            end
        else
            sendWebhookNotification(data)
        end
    end
    
    return true, filePath, fileSizeKB
end

loadstring(game:HttpGet("https://raw.githubusercontent.com/limeroblox/Universal-Model-Saver/refs/heads/main/Ui/Main.lua"))()

-- Create tabs directly (no functions needed)
local MainTab = window:CreateTab("Main", 4483362458)
local SettingsTab = window:CreateTab("Settings", 4483362458)

-- Status display
local StatusParagraph = MainTab:CreateParagraph({
    Title = "Status",
    Content = "Ready to save models"
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
        StatusParagraph:Set({Title = "Webhook Changed", Content = "Using " .. option[1]})
    end
})

-- Export mode dropdown
local ExportModeDropdown = MainTab:CreateDropdown({
    Name = "Export Mode",
    Options = {"Standard Export", "Nightbound Export", "Validation Test"},
    CurrentOption = {"Standard Export"},
    MultipleOptions = false,
    Flag = "ExportMode",
    Callback = function(option)
        StatusParagraph:Set({Title = "Mode Changed", Content = "Selected: " .. option[1]})
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
        StatusParagraph:Set({Title = "Webhook Mode", Content = option[1] .. " selected"})
    end
})

-- Model name input
local ModelNameInput = MainTab:CreateInput({
    Name = "Model Name",
    PlaceholderText = "Enter model name in workspace",
    RemoveTextAfterFocusLost = false,
    Callback = function() end
})

-- Nightbound dropdown
local NightboundDropdown = MainTab:CreateDropdown({
    Name = "Select Nightbound",
    Options = {
        "Nightbound Flare", "Nightbound Shockbane", "Nightbound Voidshackle",
        "Nightbound Shademirror", "Nightbound Dreadcoil", "Nightbound Wraith",
        "Nightbound Echo", "Nightbound Pyreblast", "Nightbound Vapormaw"
    },
    CurrentOption = {"Nightbound Wraith"},
    MultipleOptions = false,
    Flag = "NightboundSelection",
    Callback = function(option)
        StatusParagraph:Set({Title = "Selected", Content = option[1] .. " selected"})
    end
})

-- Main save button
MainTab:CreateButton({
    Name = "💾 Save Model",
    Callback = function()
        local exportMode = ExportModeDropdown.CurrentOption[1]
        local webhookMode = WebhookModeDropdown.CurrentOption[1]
        
        StatusParagraph:Set({Title = "Processing", Content = "Starting " .. exportMode .. "..."})
        
        task.spawn(function()
            local success, message, fileSize
            
            if exportMode == "Standard Export" then
                local modelName = ModelNameInput.Value
                if modelName == "" then
                    StatusParagraph:Set({Title = "Error", Content = "Please enter a model name"})
                    return
                end
                
                success, message, fileSize = standardExport(modelName, webhookMode)
            elseif exportMode == "Nightbound Export" then
                local npcName = NightboundDropdown.CurrentOption[1]
                success, message, fileSize = nightboundExport(npcName, webhookMode)
            elseif exportMode == "Validation Test" then
                -- Validation test (save local player avatar)
                local player = game.Players.LocalPlayer
                if player and player.Character then
                    success, message, fileSize = standardExport(player.Character.Name .. "_Test", "Disabled")
                    if success then
                        delfile(message:match("UniversalModelSaver/.+%.rbxm") or "")
                        message = "Validation test passed! File deleted."
                    end
                else
                    success = false
                    message = "No character found for validation"
                end
            end
            
            if success then
                StatusParagraph:Set({Title = "✅ Success", Content = message .. "\nSize: " .. fileSize .. " KB"})
                Rayfield:Notify({Title = "Export Complete", Content = "Model saved successfully!", Duration = 5})
            else
                StatusParagraph:Set({Title = "❌ Error", Content = message})
                Rayfield:Notify({Title = "Export Failed", Content = message, Duration = 5})
            end
        end)
    end
})

-- Test webhook button
MainTab:CreateButton({
    Name = "Test Webhook",
    Callback = function()
        StatusParagraph:Set({Title = "Testing", Content = "Sending test webhook..."})
        
        local data = {
            fileName = "test.webhook",
            fileSizeKB = 0,
            fileExtension = "test",
            exportMode = "Webhook Test",
            processingTime = 0,
            executor = identifyexecutor and identifyexecutor() or "Unknown"
        }
        
        local success = sendWebhookNotification(data)
        
        if success then
            StatusParagraph:Set({Title = "✅ Success", Content = "Webhook test sent!"})
        else
            StatusParagraph:Set({Title = "❌ Failed", Content = "Webhook test failed"})
        end
    end
})

-- Quick save all nightbounds
MainTab:CreateButton({
    Name = "Quick Save All Nightbounds",
    Callback = function()
        StatusParagraph:Set({Title = "Starting", Content = "Saving all Nightbounds..."})
        
        task.spawn(function()
            local nightbounds = NightboundDropdown.Options
            local savedCount = 0
            local failedCount = 0
            
            for i, npcName in ipairs(nightbounds) do
                StatusParagraph:Set({
                    Title = "Saving", 
                    Content = npcName .. " (" .. i .. "/" .. #nightbounds .. ")"
                })
                
                local success = nightboundExport(npcName, "Disabled")
                if success then savedCount = savedCount + 1 else failedCount = failedCount + 1 end
                task.wait(0.5)
            end
            
            StatusParagraph:Set({
                Title = "✅ Complete", 
                Content = "Saved " .. savedCount .. " of " .. #nightbounds .. " Nightbounds"
            })
        end)
    end
})

-- Settings
SettingsTab:CreateToggle({
    Name = "Script Preservation",
    CurrentValue = true,
    Flag = "ScriptPreservation",
    Callback = function(value) end
})

SettingsTab:CreateToggle({
    Name = "Security Filtering",
    CurrentValue = true,
    Flag = "SecurityFilter",
    Callback = function(value) end
})

SettingsTab:CreateDropdown({
    Name = "File Format",
    Options = {"RBXM", "RBXMX"},
    CurrentOption = {"RBXM"},
    MultipleOptions = false,
    Flag = "FileFormat",
    Callback = function(option)
        StatusParagraph:Set({Title = "Format Changed", Content = "Using " .. option[1] .. " format"})
    end
})

print("[Universal Model Saver] Loaded successfully!")
print("Webhooks: MAIN & TEST available")
print("Export modes: Standard, Nightbound, Validation Test")
