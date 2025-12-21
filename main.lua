-- Universal Model Saver v2.0
-- Enhanced version with multiple export modes, webhook support, and advanced features

-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Configuration
local CONFIG = {
    WEBHOOK_URL = "https://discord.com/api/webhooks/1450381715309592620/nAMQJifMff6I3Lddmj9drNDDU6cl4m0lXPU-1Ca5hIZzLabVKD7BeaEtLYvmRb2HmGtq", -- Set your webhook URL
    EXPORT_DIRECTORY = "Universal-Model-Saver/Exports",
    NIGHTBOUND_EXPORT_DIR = "Universal-Model-Saver/Nightbound",
    AVATAR_TEST_DIR = "Universal-Model-Saver/ValidationTests",
    ALLOWED_SCRIPT_TYPES = {"LocalScript", "ModuleScript"},
    DISALLOWED_SCRIPT_TYPES = {"Script"}, -- For security filtering
    NIGHTBOUND_NAMES = {
        "Nightbound Flare",
        "Nightbound Shockbane", 
        "Nightbound Voidshackle",
        "Nightbound Shademirror",
        "Nightbound Dreadcoil",
        "Nightbound Wraith",
        "Nightbound Echo",
        "Nightbound Pyreblast",
        "Nightbound Vapormaw"
    }
}

-- Utility Functions
local function ensureDirectories()
    local dirs = {CONFIG.EXPORT_DIRECTORY, CONFIG.NIGHTBOUND_EXPORT_DIR, CONFIG.AVATAR_TEST_DIR}
    for _, dir in ipairs(dirs) do
        if not isfolder(dir) then
            makefolder(dir)
        end
    end
end

local function getExecutorName()
    if syn then return "Synapse X" end
    if getexecutorname then return getexecutorname() end
    if identifyexecutor then return identifyexecutor() end
    return "Unknown Executor"
end

local function filterScripts(model)
    -- Remove disallowed scripts for security
    for _, obj in ipairs(model:GetDescendants()) do
        if table.find(CONFIG.DISALLOWED_SCRIPT_TYPES, obj.ClassName) then
            obj:Destroy()
        end
    end
    return model
end

local function prepareModelForExport(model)
    -- Clone and prepare model
    local clone = model:Clone()
    
    -- Ensure everything is archivable
    for _, descendant in ipairs(clone:GetDescendants()) do
        pcall(function()
            descendant.Archivable = true
        end
    end
    clone.Archivable = true
    
    -- Apply script filtering
    clone = filterScripts(clone)
    
    return clone
end

-- Webhook Functions
local function getRequestFunction()
    if syn and syn.request then
        return syn.request
    elseif request then
        return request
    elseif http and http.request then
        return http.request
    else
        warn("HTTP request function not available")
        return nil
    end
end

local function buildWebhookFormat(data)
    return {
        username = "Universal Model Saver",
        embeds = {{
            title = "Export Complete",
            color = data.success and 0x00FF00 or 0xFF0000,
            description = data.description or "**Model export completed**",
            fields = {
                { name = "File", value = "`" .. data.fileName .. "`", inline = true },
                { name = "Size", value = data.fileSizeKB .. " KB", inline = true },
                { name = "Type", value = data.fileExtension or "rbxm", inline = true },
                { name = "Export Mode", value = data.exportMode, inline = true },
                { name = "Processing Time", value = string.format("%.2f seconds", data.processingTime), inline = true },
                { name = "Executor", value = "```" .. data.executor .. "```", inline = false }
            },
            thumbnail = {
                url = "https://static.wikitide.net/blackoutwiki/5/54/Flare.png"
            },
            footer = {
                text = "Universal Model Saver v2.0 • " .. os.date("%Y-%m-%d %H:%M:%S")
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
end

local function sendWebhookNotification(data, fileContent)
    local requestFunc = getRequestFunction()
    if not requestFunc then
        warn("[Webhook] No request function available")
        return false
    end
    
    if fileContent and data.autoUpload then
        -- Send with file attachment
        local boundary = "----WebKitFormBoundary" .. tostring(math.random(100000, 999999))
        local payload = buildWebhookFormat(data)
        
        local body = "--" .. boundary .. "\r\n"
        body = body .. 'Content-Disposition: form-data; name="payload_json"\r\n'
        body = body .. "Content-Type: application/json\r\n\r\n"
        body = body .. HttpService:JSONEncode(payload) .. "\r\n"
        
        body = body .. "--" .. boundary .. "\r\n"
        body = body .. 'Content-Disposition: form-data; name="file"; filename="' .. data.fileName .. '"\r\n'
        body = body .. "Content-Type: application/octet-stream\r\n\r\n"
        body = body .. fileContent .. "\r\n"
        body = body .. "--" .. boundary .. "--\r\n"
        
        local success, response = pcall(function()
            return requestFunc({
                Url = CONFIG.WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
                },
                Body = body
            })
        end)
        
        return success and response and response.Success
    else
        -- Send notification only
        local payload = buildWebhookFormat(data)
        local success, response = pcall(function()
            return requestFunc({
                Url = CONFIG.WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        
        return success and response and response.Success
    end
end

-- SaveInstance Management
local function getSaveInstanceFunction()
    -- Try to find saveinstance
    local saveFunc = saveinstance or save_instance or (syn and syn.saveinstance)
    
    if not saveFunc then
        -- Load Universal Syn SaveInstance
        local success, loadedFunc = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true))()
        end)
        
        if success and type(loadedFunc) == "function" then
            return loadedFunc, false -- false = not native
        else
            warn("[Error] Could not load saveinstance function")
            return nil
        end
    end
    
    return saveFunc, true -- true = native
end

local function saveModel(model, filePath, mode)
    local saveFunc, isNative = getSaveInstanceFunction()
    if not saveFunc then return false end
    
    local startTime = os.clock()
    local success = false
    
    if isNative then
        -- Native saveinstance
        local originalThread
        if setthreadidentity then
            originalThread = getthreadidentity and getthreadidentity() or 2
            setthreadidentity(7)
        end
        
        local attempts = {
            function() saveFunc({Objects = {model}, FileName = filePath}) end,
            function() saveFunc(model, filePath) end
        }
        
        for i, attempt in ipairs(attempts) do
            local ok, err = pcall(attempt)
            if ok then
                success = true
                break
            else
                warn("[Save] Attempt #" .. i .. " failed:", err)
            end
        end
        
        if setthreadidentity and originalThread then
            setthreadidentity(originalThread)
        end
    else
        -- Universal Syn SaveInstance
        local ok, err = pcall(function()
            saveFunc({
                Object = model,
                FileName = filePath:match("([^/\\]+)$") or "model.rbxm",
                Mode = "Model",
                Decompile = mode == "decompile",
                IgnoreNotArchivable = true,
                ShowStatus = false
            })
        end)
        success = ok
        if not ok then
            warn("[Save] USSI save failed:", err)
        end
    end
    
    local processingTime = os.clock() - startTime
    return success, processingTime
end

-- Export Modes
local function standardExport(model, modelName, webhookMode)
    ensureDirectories()
    
    local fileName = modelName:gsub("%s+", "_")
    local filePath = CONFIG.EXPORT_DIRECTORY .. "/" .. fileName .. ".rbxm"
    
    -- Delete old file if exists
    if isfile(filePath) then
        delfile(filePath)
    end
    
    -- Prepare and save model
    local preparedModel = prepareModelForExport(model)
    local success, processingTime = saveModel(preparedModel, filePath, "standard")
    preparedModel:Destroy()
    
    if not success then
        return false, "Failed to save model"
    end
    
    -- Verify file was created
    task.wait(0.5)
    if not isfile(filePath) then
        return false, "File was not created"
    end
    
    -- Read file for webhook
    local fileContent = readfile(filePath)
    local fileSizeKB = math.floor(#fileContent / 1024 * 100) / 100
    
    -- Send webhook if enabled
    if webhookMode ~= "disabled" then
        local data = {
            fileName = fileName .. ".rbxm",
            fileSizeKB = fileSizeKB,
            fileExtension = "rbxm",
            exportMode = "Standard Export",
            processingTime = processingTime,
            executor = getExecutorName(),
            success = true,
            description = "**Standard export completed successfully**"
        }
        
        local autoUpload = webhookMode == "auto_upload"
        sendWebhookNotification(data, autoUpload and fileContent or nil)
    end
    
    return true, filePath, fileSizeKB, processingTime
end

local function nightboundExport(npcName, webhookMode)
    ensureDirectories()
    
    -- Find Nightbound NPC
    local npc = nil
    local npcFolder = workspace:FindFirstChild("NPCs")
    
    if npcFolder then
        for _, subFolder in ipairs({"Hostile", "Custom"}) do
            local folder = npcFolder:FindFirstChild(subFolder)
            if folder then
                npc = folder:FindFirstChild(npcName)
                if npc then break end
            end
        end
    end
    
    if not npc then
        return false, "Nightbound NPC not found"
    end
    
    -- Export with standard function but to Nightbound directory
    local originalDir = CONFIG.EXPORT_DIRECTORY
    CONFIG.EXPORT_DIRECTORY = CONFIG.NIGHTBOUND_EXPORT_DIR
    
    local success, filePath, fileSizeKB, processingTime = standardExport(npc, npcName, webhookMode)
    
    CONFIG.EXPORT_DIRECTORY = originalDir
    
    return success, success and ("Nightbound export completed: " .. filePath) or "Failed to export Nightbound",
           fileSizeKB, processingTime
end

local function validationTest()
    ensureDirectories()
    
    local player = game:GetService("Players").LocalPlayer
    if not player.Character then
        return false, "No character found"
    end
    
    local fileName = "AvatarValidation_" .. player.Name .. "_" .. os.time()
    local filePath = CONFIG.AVATAR_TEST_DIR .. "/" .. fileName .. ".rbxm"
    
    -- Export avatar
    local success, processingTime = saveModel(player.Character, filePath, "validation")
    
    if not success then
        return false, "Failed to save avatar for validation"
    end
    
    -- Verify file
    task.wait(0.5)
    if not isfile(filePath) then
        return false, "Validation file not created"
    end
    
    -- Read and delete (for space conservation)
    local fileContent = readfile(filePath)
    local fileSizeKB = math.floor(#fileContent / 1024 * 100) / 100
    
    -- Delete after validation
    delfile(filePath)
    
    return true, "Validation completed successfully. File size: " .. fileSizeKB .. " KB (deleted)", 
           fileSizeKB, processingTime
end

-- UI Initialization
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Universal Model Saver v2.0",
    LoadingTitle = "Universal Model Saver",
    LoadingSubtitle = "by Haxel | Enhanced Edition",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "UniversalModelSaver",
        FileName = "Configuration"
    },
    Discord = {
        Enabled = false,
        Invite = "https://discord.gg/wx4ThpAsmw",
        RememberJoins = true
    },
    KeySystem = false
})

-- Create Tabs
local MainTab = Window:CreateTab("Main", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)
local AboutTab = Window:CreateTab("About", 4483362458)

-- Status Display
local StatusParagraph = MainTab:CreateParagraph({
    Title = "Status",
    Content = "🔄 Initializing Universal Model Saver..."
})

-- Main Tab Elements
local ExportMode = MainTab:CreateDropdown({
    Name = "Export Mode",
    Options = {"Standard Export", "Nightbound Export", "Validation Test"},
    CurrentOption = "Standard Export",
    MultipleOptions = false,
    Flag = "ExportMode",
    Callback = function(value)
        StatusParagraph:Set({
            Title = "Mode Changed",
            Content = "Selected: " .. value
        })
    end
})

local WebhookMode = MainTab:CreateDropdown({
    Name = "Webhook Mode",
    Options = {"Auto Upload", "Notification Only", "Disabled"},
    CurrentOption = "Auto Upload",
    MultipleOptions = false,
    Flag = "WebhookMode",
    Callback = function(value)
        StatusParagraph:Set({
            Title = "Webhook Mode",
            Content = value .. " selected"
        })
    end
})

local ModelNameInput = MainTab:CreateInput({
    Name = "Model Name (for Standard Export)",
    PlaceholderText = "Enter model name or leave blank for auto-name",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        -- Store the value
    end
})

local NightboundDropdown = MainTab:CreateDropdown({
    Name = "Select Nightbound",
    Options = CONFIG.NIGHTBOUND_NAMES,
    CurrentOption = "Nightbound Wraith",
    MultipleOptions = false,
    Flag = "NightboundSelection",
    Callback = function(value)
        StatusParagraph:Set({
            Title = "Selected",
            Content = value .. " selected"
        })
    end
})

local DecompilationToggle = SettingsTab:CreateToggle({
    Name = "Script Preservation",
    CurrentValue = true,
    Flag = "ScriptPreservation",
    Callback = function(value)
        CONFIG.ALLOWED_SCRIPT_TYPES = value and {"LocalScript", "ModuleScript"} or {}
    end
})

local SecurityToggle = SettingsTab:CreateToggle({
    Name = "Security Filtering",
    CurrentValue = true,
    Flag = "SecurityFiltering",
    Callback = function(value)
        CONFIG.DISALLOWED_SCRIPT_TYPES = value and {"Script"} or {}
    end
})

local FileFormat = SettingsTab:CreateDropdown({
    Name = "File Format",
    Options = {"RBXM", "RBXMX"},
    CurrentOption = "RBXM",
    MultipleOptions = false,
    Flag = "FileFormat",
    Callback = function(value)
        StatusParagraph:Set({
            Title = "Format Changed",
            Content = "Using " .. value .. " format"
        })
    end
})

-- Main Export Button
local ExportButton = MainTab:CreateButton({
    Name = "🚀 Start Export",
    Callback = function()
        local exportMode = ExportMode.CurrentOption
        local webhookMode = WebhookMode.CurrentOption
        local webhookMap = {
            ["Auto Upload"] = "auto_upload",
            ["Notification Only"] = "notification",
            ["Disabled"] = "disabled"
        }
        
        StatusParagraph:Set({
            Title = "Status",
            Content = "🚀 Starting " .. exportMode .. "..."
        })
        
        task.spawn(function()
            local success, message, fileSize, procTime
            
            if exportMode == "Standard Export" then
                -- Get target model (you can modify this to select from workspace)
                local targetModel = workspace:FindFirstChild(ModelNameInput.Value) or workspace
                local modelName = ModelNameInput.Value ~= "" and ModelNameInput.Value or "Workspace_Export"
                
                StatusParagraph:Set({
                    Title = "Exporting",
                    Content = "Processing " .. modelName .. "..."
                })
                
                success, message, fileSize, procTime = standardExport(targetModel, modelName, webhookMap[webhookMode])
                
            elseif exportMode == "Nightbound Export" then
                local npcName = NightboundDropdown.CurrentOption
                
                StatusParagraph:Set({
                    Title = "Exporting",
                    Content = "Searching for " .. npcName .. "..."
                })
                
                success, message, fileSize, procTime = nightboundExport(npcName, webhookMap[webhookMode])
                
            elseif exportMode == "Validation Test" then
                StatusParagraph:Set({
                    Title = "Validating",
                    Content = "Testing export functionality..."
                })
                
                success, message, fileSize, procTime = validationTest()
            end
            
            -- Update status
            if success then
                StatusParagraph:Set({
                    Title = "✅ Success!",
                    Content = message .. "\nTime: " .. string.format("%.2fs", procTime) .. " | Size: " .. (fileSize or 0) .. " KB"
                })
                
                Rayfield:Notify({
                    Title = "Export Complete",
                    Content = message,
                    Duration = 6,
                    Image = 4483362458
                })
            else
                StatusParagraph:Set({
                    Title = "❌ Failed",
                    Content = message or "Export failed"
                })
                
                Rayfield:Notify({
                    Title = "Export Failed",
                    Content = message or "An error occurred",
                    Duration = 8,
                    Image = 4483362458
                })
            end
        end)
    end
})

-- Test Webhook Button
local TestWebhookButton = MainTab:CreateButton({
    Name = "Test Webhook Connection",
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
            executor = getExecutorName(),
            success = true,
            description = "**Webhook connection test successful**"
        }
        
        local success = sendWebhookNotification(data, nil)
        
        if success then
            StatusParagraph:Set({
                Title = "✅ Success",
                Content = "Webhook test sent successfully!"
            })
            Rayfield:Notify({
                Title = "Webhook Test",
                Content = "Discord webhook is working correctly",
                Duration = 5
            })
        else
            StatusParagraph:Set({
                Title = "❌ Failed",
                Content = "Webhook test failed. Check console."
            })
        end
    end
})

-- Quick Export All Nightbounds
local QuickExportButton = MainTab:CreateButton({
    Name = "Quick Export All Nightbounds",
    Callback = function()
        StatusParagraph:Set({
            Title = "Starting",
            Content = "Exporting all Nightbounds..."
        })
        
        task.spawn(function()
            local savedCount = 0
            local failedCount = 0
            
            for _, npcName in ipairs(CONFIG.NIGHTBOUND_NAMES) do
                StatusParagraph:Set({
                    Title = "Exporting",
                    Content = "Processing " .. npcName .. " (" .. (savedCount + failedCount + 1) .. "/" .. #CONFIG.NIGHTBOUND_NAMES .. ")"
                })
                
                local success = nightboundExport(npcName, "disabled")
                
                if success then
                    savedCount = savedCount + 1
                else
                    failedCount = failedCount + 1
                end
                
                task.wait(1) -- Delay to prevent rate limiting
            end
            
            StatusParagraph:Set({
                Title = "✅ Complete",
                Content = "Exported " .. savedCount .. " Nightbounds" .. (failedCount > 0 and " (" .. failedCount .. " failed)" or "")
            })
            
            Rayfield:Notify({
                Title = "Batch Export Complete",
                Content = "Successfully exported " .. savedCount .. " of " .. #CONFIG.NIGHTBOUND_NAMES .. " Nightbounds",
                Duration = 8
            })
        end)
    end
})

-- About Tab Content
AboutTab:CreateLabel("Universal Model Saver v2.0")
AboutTab:CreateLabel("Enhanced edition with multiple export modes")
AboutTab:CreateLabel("")
AboutTab:CreateParagraph({
    Title = "Features",
    Content = "• Standard Export\n• Nightbound Export\n• Validation Testing\n• Webhook Integration\n• Script Preservation\n• Security Filtering"
})
AboutTab:CreateParagraph({
    Title = "Credits",
    Content = "Created by Haxel\nInspired by Universal Syn SaveInstance\nSpecial thanks to the Roblox developer community"
})
AboutTab:CreateButton({
    Name = "Join Discord Server",
    Callback = function()
        if request then
            request({
                Url = "http://localhost:6463/rpc?v=1",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Origin"] = "https://discord.com"
                },
                Body = HttpService:JSONEncode({
                    cmd = "INVITE_BROWSER",
                    args = {
                        code = "wx4ThpAsmw"
                    },
                    nonce = HttpService:GenerateGUID(false)
                })
            })
        else
            Rayfield:Notify({
                Title = "Discord",
                Content = "Join: https://discord.gg/wx4ThpAsmw",
                Duration = 10
            })
        end
    end
})

-- Initialize
ensureDirectories()
StatusParagraph:Set({
    Title = "✅ Ready",
    Content = "Select export mode and click Start Export\nExecutor: " .. getExecutorName()
})

-- Set webhook URL from input if needed
local WebhookURLInput = SettingsTab:CreateInput({
    Name = "Webhook URL",
    PlaceholderText = "Enter Discord webhook URL",
    RemoveTextAfterFocusLost = false,
    Callback = function(value)
        if value:find("discord.com/api/webhooks") then
            CONFIG.WEBHOOK_URL = value
            StatusParagraph:Set({
                Title = "Webhook Updated",
                Content = "Webhook URL has been updated"
            })
        end
    end
})

print("[Universal Model Saver] v2.0 loaded successfully!")
print("Export modes: Standard, Nightbound, Validation")
print("Webhook support: " .. (getRequestFunction() and "Enabled" or "Disabled"))
