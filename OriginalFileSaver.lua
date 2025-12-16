local WEBHOOK_URL = "https://discord.com/api/webhooks/1450349493743652955/d-BpW7PGhWHfakh-UG1nbDWekGXA_1rUaFG6QC42iWowkI7ALseaEXmtXIFkHQYXr2DW"
local HttpService = game:GetService("HttpService")

-- Ensure request function is available
local request
if syn and syn.request then
    request = syn.request
elseif http and http.request then
    request = http.request
elseif request == nil then
    -- Try to find request function
    request = function(options)
        warn("Request function not available, webhook sending will fail")
        return {Success = false, StatusCode = 0}
    end
end

-- Function to send file to Discord webhook using proper file upload
local function sendFileToWebhook(filePath, npcName)
    if not isfile(filePath) then
        warn("[Webhook] File does not exist:", filePath)
        return false
    end
    
    -- Read the file
    local success, fileData = pcall(readfile, filePath)
    if not success then
        warn("[Webhook] Failed to read file:", filePath)
        return false
    end
    
    if #fileData == 0 then
        warn("[Webhook] File is empty:", filePath)
        return false
    end
    
    local fileName = filePath:match("[^/\\]+$")
    local fileSizeKB = math.floor(#fileData / 1024 * 100) / 100
    
    print("[Webhook] Uploading:", fileName, "Size:", #fileData, "bytes")
    
    -- Create form data for Discord
    local boundary = "----WebKitFormBoundary" .. tostring(math.random(100000, 999999))
    
    -- Build the form data properly
    local formData = {}
    
    -- JSON payload part
    -- Create the payload
    local payload = {
        username = "Haxel's Cool Webhook",
        embeds = {{
            title = "RBXM Saved",
            description = "**Export Completed**",
            color = 0x2B2D31,
            fields = {
                { name = "File", value = "`" .. fileName .. "`", inline = true },
                { name = "Size", value = fileSizeKB .. " KB", inline = true },
                { name = "Type", value = filePath:match("%.(.+)$") or "rbxm", inline = true }
            },
            thumbnail = { url = "https://static.wikitide.net/blackoutwiki/5/54/Flare.png" }, 
            footer = { text = "Saveinstance()" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    
    -- Create the multipart body
    local body = ""
    
    -- Add JSON payload
    body = body .. "--" .. boundary .. "\r\n"
    body = body .. 'Content-Disposition: form-data; name="payload_json"\r\n'
    body = body .. "Content-Type: application/json\r\n\r\n"
    body = body .. HttpService:JSONEncode(payload) .. "\r\n"
    
    -- Add file content
    body = body .. "--" .. boundary .. "\r\n"
    body = body .. 'Content-Disposition: form-data; name="file"; filename="' .. fileName .. '"\r\n'
    body = body .. "Content-Type: application/octet-stream\r\n\r\n"
    
    -- Combine everything
    local fullBody = body .. fileData .. "\r\n--" .. boundary .. "--\r\n"
    
    -- Send the request
    local success, response = pcall(function()
        return request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
            },
            Body = fullBody
        })
    end)
    
    if success and response then
        if response.Success then
            print("[Webhook] ✓ File uploaded successfully to Discord!")
            
            -- Try to parse Discord's response
            if response.Body then
                local ok, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
                if ok and data then
                    print("[Webhook] Discord response: File uploaded")
                    if data.attachments and data.attachments[1] then
                        print("[Webhook] File URL:", data.attachments[1].url)
                    end
                end
            end
            
            return true
        else
            warn("[Webhook] ✗ Discord rejected upload. Status:", response.StatusCode)
            if response.Body then
                warn("[Webhook] Error response:", response.Body)
                -- Check for common Discord errors
                if response.Body:find("Invalid Form Body") then
                    warn("[Webhook] This is usually due to malformed form data")
                elseif response.Body:find("rate limited") then
                    warn("[Webhook] You're being rate limited! Wait a bit")
                end
            end
            return false
        end
    else
        warn("[Webhook] ✗ Request failed:", response)
        return false
    end
end

-- Alternative: Simple webhook without file attachment (just notification)
local function sendSimpleNotification(npcName, filePath, sendFile)
    local fileName = filePath:match("[^/\\]+$")
    local fileSizeKB = 0
    
    if isfile(filePath) then
        local fileData = readfile(filePath)
        fileSizeKB = math.floor(#fileData / 1024 * 100) / 100
    end
    
    -- Create the payload
    local payload = {
        username = "Haxel's Cool Webhook",
        embeds = {{
            title = "RBXM Saved",
            description = "**Export Completed**",
            color = 0x2B2D31,
            fields = {
                { name = "File", value = "`" .. fileName .. "`", inline = true },
                { name = "Size", value = fileSizeKB .. " KB", inline = true },
                { name = "Type", value = filePath:match("%.(.+)$") or "rbxm", inline = true }
            },
            thumbnail = { url = "https://static.wikitide.net/blackoutwiki/5/54/Flare.png" }, 
            footer = { text = "Saveinstance()" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
    
    local success, response = pcall(function()
        return request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    return success and response and response.Success
end


--// Nightbound Saver using Rayfield Interface Suite (RBXM mode)
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Nightbound Saver",
    LoadingTitle = "Nightbound Saver",
    LoadingSubtitle = "by HAXEL",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "NightboundSaver",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 0)

local StatusParagraph = MainTab:CreateParagraph({
    Title = "Status",
    Content = "Initializing..."
})

local Dropdown = MainTab:CreateDropdown({
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
    Callback = function(Option) end,
})

--// SAVEINSTANCE DETECTION
StatusParagraph:Set({Title = "Status", Content = "Detecting saveinstance..."})
local saveinstance_func = saveinstance or save_instance or (syn and syn.saveinstance)
local isNativeSave = true

if not saveinstance_func then
    StatusParagraph:Set({Title = "Status", Content = "Loading Universal SynSaveInstance..."})
    local RepoURL = "https://raw.githubusercontent.com/luau/SynSaveInstance/main/"
    local success, err = pcall(function()
        saveinstance_func = loadstring(game:HttpGet(RepoURL .. "saveinstance.luau", true))()
    end)

    if success and typeof(saveinstance_func) == "function" then
        isNativeSave = false
        StatusParagraph:Set({Title = "Status", Content = "USSI loaded successfully"})
    else
        StatusParagraph:Set({Title = "Status", Content = "Failed to load saveinstance"})
        Rayfield:Notify({Title = "Error", Content = "Failed to load saveinstance function!", Duration = 10})
        return
    end
else
    StatusParagraph:Set({Title = "Status", Content = "Native saveinstance ready"})
end

--// WEBHOOK SETTINGS
local WebhookMode = MainTab:CreateDropdown({
    Name = "Webhook Mode",
    Options = {
        "Auto Upload to Discord",
        "Notification Only",
        "Disabled"
    },
    CurrentOption = {"Auto Upload to Discord"},
    MultipleOptions = false,
    Flag = "WebhookMode",
    Callback = function(value) end
})

-- Function to save NPC
local function saveNPC(npc, filePath, baseName)
    local success = false
    
    if isNativeSave then
        local originalThread
        if setthreadidentity then
            originalThread = getthreadidentity and getthreadidentity() or 2
            setthreadidentity(7)
        end
        
        local saveAttempts = {
            function() saveinstance_func({Objects = {npc}, FileName = filePath}) end,
            function() saveinstance_func(npc, filePath) end,
            function() saveinstance_func(filePath) end
        }
        
        for i, attempt in ipairs(saveAttempts) do
            local ok, err = pcall(attempt)
            if ok then
                success = true
                print("[Saver] Save successful with attempt #" .. i)
                break
            else
                warn("[Saver] Attempt #" .. i .. " failed:", err)
            end
        end
        
        if setthreadidentity and originalThread then
            setthreadidentity(originalThread)
        end
    else
        local ok, err = pcall(function()
            saveinstance_func({
                Object = npc,
                FileName = baseName .. ".rbxm",
                Mode = "Model",
                Decompile = false,
                IgnoreNotArchivable = true,
                ShowStatus = false,
                Path = "NightboundExports"
            })
        end)
        success = ok
        if not ok then
            warn("[Saver] USSI save failed:", err)
        end
    end
    
    return success
end

-- Main Save Button
local SaveButton = MainTab:CreateButton({
    Name = "📥 Save Selected Nightbound",
    Callback = function()
        local selected = Dropdown.CurrentOption[1]
        local webhookMode = WebhookMode.CurrentOption[1]
        local sendWebhook = webhookMode ~= "Disabled"
        local autoUpload = webhookMode == "Auto Upload to Discord"
        
        StatusParagraph:Set({Title = "Status", Content = "🔍 Searching for " .. selected .. "..."})

        task.spawn(function()
            local foundNPC = nil
            local successFind, errFind = pcall(function()
                local allNPCs = workspace:FindFirstChild("NPCs")
                if allNPCs then
                    for _, folder in {allNPCs:FindFirstChild("Hostile"), allNPCs:FindFirstChild("Custom")} do
                        if folder then
                            foundNPC = folder:FindFirstChild(selected)
                            if foundNPC then
                                break
                            end
                        end
                    end
                end
            end)

            if not successFind or not foundNPC then
                StatusParagraph:Set({Title = "Status", Content = "❌ " .. selected .. " not found"})
                Rayfield:Notify({
                    Title = "NPC Not Found",
                    Content = "Check if the NPC is spawned in-game",
                    Duration = 5
                })
                return
            end

            StatusParagraph:Set({Title = "Status", Content = "✅ Found " .. selected .. ", preparing save..."})

            -- Create export directory
            local baseExportDir = "NightboundExports"
            if not isfolder(baseExportDir) then
                makefolder(baseExportDir)
            end

            -- Create filename
            local baseName = selected:gsub(" ", "")
            local rbxmPath = baseExportDir .. "/" .. baseName .. ".rbxm"
            
            -- Delete old file if it exists
            if isfile(rbxmPath) then
                pcall(delfile, rbxmPath)
            end

            -- Clone and prepare NPC
            local npcClone = foundNPC:Clone()
            for _, descendant in pairs(npcClone:GetDescendants()) do
                pcall(function()
                    descendant.Archivable = true
                end)
            end
            npcClone.Archivable = true

            -- Save the NPC
            StatusParagraph:Set({Title = "Status", Content = "💾 Saving " .. selected .. " to file..."})
            
            local saveSuccess = saveNPC(npcClone, rbxmPath, baseName)
            npcClone:Destroy()

            if not saveSuccess then
                StatusParagraph:Set({Title = "Status", Content = "❌ Failed to save " .. selected})
                Rayfield:Notify({
                    Title = "Save Failed",
                    Content = "Saveinstance function failed",
                    Duration = 8
                })
                return
            end

            -- Wait for file to be written
            local fileSaved = false
            local fileSize = 0
            
            for waitAttempt = 1, 30 do
                task.wait(0.5)
                if isfile(rbxmPath) then
                    local data = readfile(rbxmPath)
                    if #data > 100 then
                        fileSaved = true
                        fileSize = #data
                        break
                    end
                end
            end

            if not fileSaved then
                StatusParagraph:Set({Title = "Status", Content = "❌ File not created properly"})
                return
            end

            -- File saved successfully
            local fileSizeKB = math.floor(fileSize / 1024 * 100) / 100
            StatusParagraph:Set({Title = "Status", Content = "✅ Saved " .. selected .. " (" .. fileSizeKB .. " KB)"})

            -- Handle webhook
            if sendWebhook then
                StatusParagraph:Set({Title = "Status", Content = "📤 Sending to Discord..."})
                
                if autoUpload then
                    -- Try to auto-upload the file
                    local uploadSuccess = sendFileToWebhook(rbxmPath, selected)
                    
                    if uploadSuccess then
                        StatusParagraph:Set({Title = "Status", Content = "✅ File uploaded to Discord!"})
                        Rayfield:Notify({
                            Title = "Complete!",
                            Content = selected .. " saved and uploaded to Discord",
                            Duration = 8
                        })
                    else
                        -- Fallback to notification only
                        sendSimpleNotification(selected, rbxmPath, false)
                        StatusParagraph:Set({Title = "Status", Content = "✅ Saved locally (upload failed)"})
                        Rayfield:Notify({
                            Title = "Saved Locally",
                            Content = selected .. " saved to NightboundExports folder\n(Upload to Discord failed)",
                            Duration = 8
                        })
                    end
                else
                    -- Notification only mode
                    sendSimpleNotification(selected, rbxmPath, true)
                    StatusParagraph:Set({Title = "Status", Content = "✅ Notification sent to Discord"})
                    Rayfield:Notify({
                        Title = "Saved with Notification",
                        Content = selected .. " saved and notification sent",
                        Duration = 8
                    })
                end
            else
                -- No webhook
                Rayfield:Notify({
                    Title = "Saved Locally",
                    Content = selected .. " saved to NightboundExports folder\n(" .. fileSizeKB .. " KB)",
                    Duration = 8
                })
            end
            
            -- Final status
            local statusText = "✅ " .. selected .. " saved (" .. fileSizeKB .. " KB)"
            if sendWebhook then
                statusText = statusText .. (autoUpload and " 📤 Uploaded" or " 💬 Notified")
            end
            StatusParagraph:Set({Title = "Status", Content = statusText})
        end)
    end,
})

-- Test Webhook Button
local DebugButton = MainTab:CreateButton({
    Name = "Test Discord Webhook",
    Callback = function()
        StatusParagraph:Set({Title = "Status", Content = "Testing webhook connection..."})
        
        -- Create the payload
    local payload = {
        username = "Haxel's Cool Webhook",
        embeds = {{
            title = "Test",
            description = "**HTTP Connection Went Through**",
            color = 0x2B2D31,
            fields = {
                { name = "File", value = "`" .. fileName .. "`", inline = true },
                { name = "Size", value = fileSizeKB .. " KB", inline = true },
                { name = "Type", value = filePath:match("%.(.+)$") or "rbxm", inline = true }
            },
            thumbnail = { url = "https://static.wikitide.net/blackoutwiki/5/54/Flare.png" }, 
            footer = { text = "Saveinstance()" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }
        
        local success, response = pcall(function()
            return request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        
        if success and response and response.Success then
            StatusParagraph:Set({Title = "Status", Content = "✅ Webhook test successful!"})
            Rayfield:Notify({
                Title = "Webhook Test",
                Content = "Discord webhook is working correctly",
                Duration = 5
            })
        else
            StatusParagraph:Set({Title = "Status", Content = "❌ Webhook test failed"})
            Rayfield:Notify({
                Title = "Webhook Test Failed",
                Content = "Check console for details",
                Duration = 5
            })
        end
    end,
})

-- Quick Save All Button (for when you want to save everything at once)
local QuickSaveButton = MainTab:CreateButton({
    Name = "Quick Save All Nightbounds",
    Callback = function()
        StatusParagraph:Set({Title = "Status", Content = "⚠️ This will take a while..."})
        
        task.spawn(function()
            local allNPCs = workspace:FindFirstChild("NPCs")
            if not allNPCs then
                StatusParagraph:Set({Title = "Status", Content = "❌ No NPCs folder found"})
                return
            end
            
            -- Create export directory
            if not isfolder("NightboundExports") then
                makefolder("NightboundExports")
            end
            
            local savedCount = 0
            local npcList = {
                "Nightbound Flare", "Nightbound Shockbane", "Nightbound Voidshackle",
                "Nightbound Shademirror", "Nightbound Dreadcoil", "Nightbound Wraith",
                "Nightbound Echo", "Nightbound Pyreblast", "Nightbound Vapormaw"
            }
            
            for _, npcName in ipairs(npcList) do
                StatusParagraph:Set({Title = "Status", Content = "🔍 Looking for " .. npcName .. "..."})
                
                local foundNPC = nil
                for _, folder in {allNPCs:FindFirstChild("Hostile"), allNPCs:FindFirstChild("Custom")} do
                    if folder then
                        foundNPC = folder:FindFirstChild(npcName)
                        if foundNPC then break end
                    end
                end
                
                if foundNPC then
                    local baseName = npcName:gsub(" ", "")
                    local filePath = "NightboundExports/" .. baseName .. ".rbxm"
                    
                    -- Save the NPC
                    local npcClone = foundNPC:Clone()
                    npcClone.Archivable = true
                    for _, desc in npcClone:GetDescendants() do
                        pcall(function() desc.Archivable = true end)
                    end
                    
                    local success = saveNPC(npcClone, filePath, baseName)
                    npcClone:Destroy()
                    
                    if success then
                        savedCount = savedCount + 1
                        print("[QuickSave] Saved:", npcName)
                    end
                end
                
                task.wait(1) -- Delay to avoid rate limiting
            end
            
            StatusParagraph:Set({Title = "Status", Content = "✅ Saved " .. savedCount .. " Nightbounds"})
            Rayfield:Notify({
                Title = "Quick Save Complete",
                Content = "Saved " .. savedCount .. " NPCs to NightboundExports",
                Duration = 8
            })
        end)
    end,
})

StatusParagraph:Set({Title = "Status", Content = "✅ Ready - Select a Nightbound and Save"})
