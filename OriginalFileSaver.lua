-- Universal Model Saver - Main Logic File
-- This file contains all the saving logic and connects to your UI

local HttpService = game:GetService("HttpService")

-- Webhook Configuration
local WEBHOOKS = {
    TEST = "https://discord.com/api/webhooks/1450381715309592620/nAMQJifMff6I3Lddmj9drNDDU6cl4m0lXPU-1Ca5hIZzLabVKD7BeaEtLYvmRb2HmGtq",
    MAIN = "https://discord.com/api/webhooks/1450349493743652955/d-BpW7PGhWHfakh-UG1nbDWekGXA_1rUaFG6QC42iWowkI7ALseaEXmtXIFkHQYXr2DW"
}

local currentWebhook = WEBHOOKS.MAIN

-- Function to build webhook embed format
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
            thumbnail = {
                url = "https://static.wikitide.net/blackoutwiki/5/54/Flare.png"
            },
            footer = {
                text = "Saved By Universal Model Saver v1.0 • " .. os.date("%Y-%m-%d %H:%M:%S")
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
end

-- Get request function for webhooks
local function getRequestFunction()
    if syn and syn.request then
        return syn.request
    elseif http and http.request then
        return http.request
    elseif request then
        return request
    else
        return nil
    end
end

-- Function to send webhook with file attachment
-- Function to send webhook with file attachment
local function sendWebhookWithFile(filePath, data, webhookUrl)
    if not isfile(filePath) then
        return false, "File does not exist"
    end
    
    local fileData = readfile(filePath)
    if #fileData == 0 then
        return false, "File is empty"
    end
    
    local requestFunc = getRequestFunction()
    if not requestFunc then
        return false, "No HTTP request function available"
    end
    
    local boundary = "----WebKitFormBoundary" .. tostring(math.random(100000, 999999))
    local payload = buildWebhookFormat(data)
    
    -- Build the multipart form data correctly
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
            Url = webhookUrl or currentWebhook,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
            },
            Body = body
        })
    end)
    
    return success and response and response.Success, success and response or "Request failed"
end

-- Function to send webhook notification only (no file)
local function sendWebhookNotification(data, webhookUrl)
    local requestFunc = getRequestFunction()
    if not requestFunc then
        return false
    end
    
    local payload = buildWebhookFormat(data)
    
    local success, response = pcall(function()
        return requestFunc({
            Url = webhookUrl or currentWebhook,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    return success and response and response.Success
end

-- Get saveinstance function
local function getSaveInstance()
    if saveinstance then
        return saveinstance, true
    elseif syn and syn.saveinstance then
        return syn.saveinstance, true
    else
        -- Try to load Universal Syn SaveInstance
        local success, saveFunc = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true))()
        end)
        
        if success and type(saveFunc) == "function" then
            return saveFunc, false
        else
            return nil, false
        end
    end
end

-- Save model function
local function saveModel(model, fileName, exportMode)
    local saveFunc, isNative = getSaveInstance()
    if not saveFunc then
        return false, "No saveinstance function found"
    end
    
    local startTime = os.time()
    
    -- Create export directory
    local exportDir = "UniversalModelSaver/Exports"
    if not isfolder(exportDir) then
        makefolder(exportDir)
    end
    
    local filePath = exportDir .. "/" .. fileName .. ".rbxm"
    
    if isfile(filePath) then
        delfile(filePath)
    end
    
    -- Prepare model
    local modelClone = model:Clone()
    for _, descendant in ipairs(modelClone:GetDescendants()) do
        pcall(function()
            descendant.Archivable = true
        end)
    end
    modelClone.Archivable = true
    
    -- Filter scripts if needed (based on your config)
    for _, script in ipairs(modelClone:GetDescendants()) do
        if script:IsA("Script") then
            script:Destroy()
        end
    end
    
    -- Save the model
    local success = false
    if isNative then
        local originalThread
        if setthreadidentity then
            originalThread = getthreadidentity()
            setthreadidentity(7)
        end
        
        local attempts = {
            function() saveFunc({Objects = {modelClone}, FileName = filePath}) end,
            function() saveFunc(modelClone, filePath) end
        }
        
        for _, attempt in ipairs(attempts) do
            local ok = pcall(attempt)
            if ok then
                success = true
                break
            end
        end
        
        if setthreadidentity and originalThread then
            setthreadidentity(originalThread)
        end
    else
        local ok = pcall(function()
            saveFunc({
                Object = modelClone,
                FileName = fileName .. ".rbxm",
                Mode = "Model",
                Decompile = false,
                IgnoreNotArchivable = true,
                ShowStatus = false,
                Path = exportDir
            })
        end)
        success = ok
    end
    
    modelClone:Destroy()
    
    if not success then
        return false, "Failed to save model"
    end
    
    -- Verify file was created
    for i = 1, 30 do
        task.wait(0.5)
        if isfile(filePath) then
            local data = readfile(filePath)
            if #data > 100 then
                local processingTime = os.time() - startTime
                local fileSizeKB = math.floor(#data / 1024 * 100) / 100
                return true, filePath, fileSizeKB, processingTime
            end
        end
    end
    
    return false, "File was not created properly"
end

-- Standard export function
local function standardExport(modelName, webhookMode)
    -- Find model in workspace
    local model = workspace:FindFirstChild(modelName)
    if not model then
        return false, "Model not found in workspace"
    end
    
    local success, filePath, fileSizeKB, processingTime = saveModel(model, modelName, "Standard")
    
    if not success then
        return false, "Export failed"
    end
    
    -- Handle webhook
    if webhookMode ~= "Disabled" then
        local data = {
            fileName = modelName .. ".rbxm",
            fileSizeKB = fileSizeKB,
            fileExtension = "rbxm",
            exportMode = "Standard Export",
            processingTime = processingTime,
            executor = identifyexecutor and identifyexecutor() or "Unknown"
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
    
    return true, "Standard export completed: " .. filePath, fileSizeKB
end

-- Nightbound export function
local function nightboundExport(npcName, webhookMode)
    -- Find Nightbound NPC
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
    
    if not npc then
        return false, "Nightbound NPC not found"
    end
    
    local success, filePath, fileSizeKB, processingTime = saveModel(npc, npcName, "Nightbound")
    
    if not success then
        return false, "Nightbound export failed"
    end
    
    -- Handle webhook
    if webhookMode ~= "Disabled" then
        local data = {
            fileName = npcName .. ".rbxm",
            fileSizeKB = fileSizeKB,
            fileExtension = "rbxm",
            exportMode = "Nightbound Export",
            processingTime = processingTime,
            executor = identifyexecutor and identifyexecutor() or "Unknown"
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
    
    return true, "Nightbound export completed: " .. filePath, fileSizeKB
end

-- Now let's properly load the UI and create elements
-- First, let's load the UI and make sure we can access Window
local Rayfield, Window

local function initializeUI()
    -- Load the Rayfield UI
    Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    
    -- Create the window
    Window = Rayfield:CreateWindow({
        Name = "Universal Model Saver",
        LoadingTitle = "Loading Assets",
        LoadingSubtitle = "made with <3 by Haxel",
        ShowText = "Universal Model Saver",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "Model Saver Folder",
            FileName = "Config"
        },
        Discord = { Enabled = false },
        KeySystem = false
    })
    
    -- Now create tabs and elements
    createUIElements()
end

local function createUIElements()
    -- Create tabs
    local MainTab = Window:CreateTab("Main", 4483362458)
    local SettingsTab = Window:CreateTab("Settings", 4483362458)
    
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
            StatusParagraph:Set({
                Title = "Webhook Changed",
                Content = "Using " .. option[1]
            })
        end
    })
    
    -- Export mode dropdown
    local ExportModeDropdown = MainTab:CreateDropdown({
        Name = "Export Mode",
        Options = {"Standard Export", "Nightbound Export"},
        CurrentOption = {"Standard Export"},
        MultipleOptions = false,
        Flag = "ExportMode",
        Callback = function(option)
            StatusParagraph:Set({
                Title = "Mode Changed",
                Content = "Selected: " .. option[1]
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
    
    -- Model name input (for standard export)
    local ModelNameInput = MainTab:CreateInput({
        Name = "Model Name",
        PlaceholderText = "Enter model name in workspace",
        RemoveTextAfterFocusLost = false,
        Callback = function(text)
            -- Store the model name
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
        Name = "💾 Save Model",
        Callback = function()
            local exportMode = ExportModeDropdown.CurrentOption[1]
            local webhookMode = WebhookModeDropdown.CurrentOption[1]
            
            StatusParagraph:Set({
                Title = "Processing",
                Content = "Starting " .. exportMode .. "..."
            })
            
            task.spawn(function()
                local success, message, fileSize
                
                if exportMode == "Standard Export" then
                    local modelName = ModelNameInput.Value
                    if modelName == "" then
                        StatusParagraph:Set({
                            Title = "Error",
                            Content = "Please enter a model name"
                        })
                        return
                    end
                    
                    success, message, fileSize = standardExport(modelName, webhookMode)
                else -- Nightbound Export
                    local npcName = NightboundDropdown.CurrentOption[1]
                    success, message, fileSize = nightboundExport(npcName, webhookMode)
                end
                
                if success then
                    StatusParagraph:Set({
                        Title = "✅ Success",
                        Content = message .. "\nSize: " .. fileSize .. " KB"
                    })
                    
                    Rayfield:Notify({
                        Title = "Export Complete",
                        Content = "Model saved successfully!",
                        Duration = 5
                    })
                else
                    StatusParagraph:Set({
                        Title = "❌ Error",
                        Content = message
                    })
                    
                    Rayfield:Notify({
                        Title = "Export Failed",
                        Content = message,
                        Duration = 5
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
                fileExtension = "test",
                exportMode = "Webhook Test",
                processingTime = 0,
                executor = identifyexecutor and identifyexecutor() or "Unknown"
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
    
    -- Quick save all nightbounds button
    MainTab:CreateButton({
        Name = "Quick Save All Nightbounds",
        Callback = function()
            StatusParagraph:Set({
                Title = "Starting",
                Content = "Saving all Nightbounds..."
            })
            
            task.spawn(function()
                local nightbounds = {
                    "Nightbound Flare", "Nightbound Shockbane", "Nightbound Voidshackle",
                    "Nightbound Shademirror", "Nightbound Dreadcoil", "Nightbound Wraith",
                    "Nightbound Echo", "Nightbound Pyreblast", "Nightbound Vapormaw"
                }
                
                local savedCount = 0
                local failedCount = 0
                
                for _, npcName in ipairs(nightbounds) do
                    StatusParagraph:Set({
                        Title = "Saving",
                        Content = npcName .. " (" .. (savedCount + failedCount + 1) .. "/" .. #nightbounds .. ")"
                    })
                    
                    local success = nightboundExport(npcName, "Disabled")
                    
                    if success then
                        savedCount = savedCount + 1
                    else
                        failedCount = failedCount + 1
                    end
                    
                    task.wait(1)
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
        Callback = function(value)
            -- Toggle script preservation
        end
    })
    
    SettingsTab:CreateToggle({
        Name = "Security Filtering",
        CurrentValue = true,
        Flag = "SecurityFilter",
        Callback = function(value)
            -- Toggle security filtering
        end
    })
    
    SettingsTab:CreateDropdown({
        Name = "File Format",
        Options = {"RBXM", "RBXMX"},
        CurrentOption = {"RBXM"},
        MultipleOptions = false,
        Flag = "FileFormat",
        Callback = function(option)
            StatusParagraph:Set({
                Title = "Format Changed",
                Content = "Using " .. option[1] .. " format"
            })
        end
    })
end

-- Initialize the UI
initializeUI()

print("[Universal Model Saver] Loaded successfully!")
print("Webhooks: MAIN & TEST available")
print("Export modes: Standard & Nightbound")
