local webhookformat = { -- Stores the webhook formating
  username = "Universal Model Saver",
    embeds = {{
        title = "Export Complete",
        color = "0x00FF00",
        fields = {
            { name = "File", value = "`" .. fileName .. "`", inline = true },
            { name = "Size", value = fileSizeKB .. " KB", inline = true },
            { name = "Type", value = fileExtension or "rbxm", inline = true },
            { name = "Export Mode", value = exportMode, inline = true },
            { name = "Processing Time", value = processingTime .. " seconds", inline = true },
            { name = "Executor", value = "```" .. executor .. "```", inline = false }
        },
        thumbnail = { url = "https://static.wikitide.net/blackoutwiki/5/54/Flare.png" },
        footer = { 
            text = "Saved By Universal Model Saver v1.0" .. os.date("%Y-%m-%d %H:%M:%S")
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}
}
loadstring(game:HttpGet("https://raw.githubusercontent.com/limeroblox/Universal-Model-Saver/refs/heads/main/Ui/Main.lua"))() -- Loads the Main UI

local Tab = Window:CreateTab("Tab Example", 4483362458) -- Title, Image
