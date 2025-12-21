local Rayfeild = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local window = Rayfeild:CreateWindow({
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
