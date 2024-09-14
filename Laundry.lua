-- Servislerin alınması
local VirtualUser = game:GetService("VirtualUser")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

-- Plot kontrolü ve varsayılan değerler
local Plot = Player.NonSaveVars.OwnsPlot.Value or nil
local MainSignal = nil

-- Yapılandırma tablosu
local Config = {
    CanGrab = {
        Normal = false,
        Silver = true,
        Gold = true,
        Emerald = true,
        Ruby = true,
        Sapphire = true,
    },
    Autofarm = {
        TrueAutoFarm = false,
        Grabbing = false,
    }
}

-- Oyuncu afk kaldığında kontrol simülasyonu
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Arsa sahipliği kontrolü
if not Plot then
    repeat
        task.wait(1)
        Library:ShowNotification("warning", "Please claim a plot.", 1)
    until Player.NonSaveVars.OwnsPlot.Value ~= nil
    Plot = Player.NonSaveVars.OwnsPlot.Value
end

-- Yardımcı Fonksiyonlar
local function Or(Variable, ...)
    for _, Value in ipairs({...}) do
        if Variable == Value then return true end
    end
    return false
end

local function FindFirstChild(Parent, Name)
    return Parent:FindFirstChild(Name)
end

local function GetClothTag(Cloth)
    local SpecialTag = Cloth:FindFirstChild("SpecialTag")
    if not SpecialTag then return "Normal" end
    return SpecialTag.Value
end

-- Kıyafet alma fonksiyonu
local function GrabClothing(Cloth)
    local clothTag = GetClothTag(Cloth)
    if Config.CanGrab[clothTag] then
        local lastPosition = Player.Character.HumanoidRootPart.CFrame
        Player.Character.HumanoidRootPart.CFrame = CFrame.new(Cloth.CFrame.Position + Vector3.new(0, 2, 0))
        
        task.delay(0.1, function()
            ReplicatedStorage.Events.GrabClothing:FireServer(Cloth)
            Player.Character.HumanoidRootPart.CFrame = lastPosition
        end)
    end
end

-- Çamaşır makinelerini yükleme fonksiyonu
local function LoadWashingMachines()
    for _, Machine in ipairs(Plot.WashingMachines:GetChildren()) do
        local Config = Machine.Config
        if not Config.Started.Value and not Config.InsertingClothes.Value and not Config.DoorMoving.Value and not Config.CycleFinished.Value then
            Player.Character.HumanoidRootPart.CFrame = Machine.MAIN.CFrame
            task.delay(0.1, function()
                ReplicatedStorage.Events.LoadWashingMachine:FireServer(Machine)
            end)
            task.wait(0.2)
            if Player.NonSaveVars.BackpackAmount.Value == 0 then break end
        end
    end
end

-- Çamaşır makinelerini boşaltma fonksiyonu
local function UnloadWashingMachines()
    for _, Machine in ipairs(Plot.WashingMachines:GetChildren()) do
        if Machine.Config.CycleFinished.Value then
            Player.Character.HumanoidRootPart.CFrame = Machine.MAIN.CFrame
            task.delay(0.1, function()
                ReplicatedStorage.Events.UnloadWashingMachine:FireServer(Machine)
            end)
            task.wait(0.2)
            if Player.NonSaveVars.BackpackAmount.Value == Player.NonSaveVars.BasketSize.Value then break end
        end
    end
end

-- True autofarm fonksiyonu
local function TrueAutofarm()
    while Config.Autofarm.TrueAutoFarm do
        if #workspace.Debris.Clothing:GetChildren() > 0 then
            if Player.NonSaveVars.BackpackAmount.Value == 0 or Player.NonSaveVars.BasketStatus.Value == "Dirty" then
                LoadWashingMachines()
                UnloadWashingMachines()
                Player.Character.HumanoidRootPart.CFrame = workspace["_FinishChute"].Entrance.CFrame
                task.wait(0.2)
                ReplicatedStorage.Events.DropClothesInChute:FireServer()
            end
        end
        task.wait()
    end
end

-- Otomatik Kıyafet Alma Toggle Fonksiyonu
local function AutoGrabClothingToggle(Value)
    Config.Autofarm.Grabbing = Value
end

-- Kullanıcıya yönelik UI ve ayarlar
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Xxtan31/LaundryGui/main/LaundryGui.txt"))()("Laundry Simulator", Enum.KeyCode.E, {}, function()
    Config.Autofarm.TrueAutoFarm = false
    Config.Autofarm.Grabbing = false
    MainSignal:Disconnect()
end)

local TabAutofarm = Library:AddTab("Autofarm")
TabAutofarm:AddToggle("True autofarm", "Runs through all the checks and functions for a full afk session.", "", Config.Autofarm.TrueAutoFarm, TrueAutofarm)

-- Diğer UI ve İşlevler
TabAutofarm:AddToggle("Auto grab open clothes", "Automatically grabs clothes depending on the selected configs.", "", Config.Autofarm.Grabbing, AutoGrabClothingToggle)

-- Sinyal Bağlantısı
MainSignal = workspace.Debris.Clothing.ChildAdded:Connect(function(Cloth)
    if Config.Autofarm.Grabbing and (Player.NonSaveVars.BackpackAmount.Value < Player.NonSaveVars.BasketSize.Value) then
        GrabClothing(Cloth)
    end
end)
