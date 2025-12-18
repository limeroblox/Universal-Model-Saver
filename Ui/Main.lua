local UniversalModelSaver = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = UniversalModelSaver:CreateWindow({
    Name = "Universal Model Saver",
    LoadingTitle = "Loading Assets",
    LoadingSubtitle = "made with <3 by Haxel",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Model Saver Folder",
        FileName = "Config"
    },
    Discord = { Enabled = false },
    KeySystem = false
})
