SafeCracker.MinigameOpen = false
SafeCracker.LockRotation = 0.0
SafeCracker.Timer = 0
SafeCracker.SoundID = nil
SafeCracker.Callback = nil

exports('StartMinigame', function(combo)
    if SafeCracker.MinigameOpen then return false end

    local p = promise.new()
    StartMinigame(combo, function(success)
        p:resolve(success)
    end)

    return Citizen.Await(p)
end)

function StartMinigame(combo, cb)
    local ped = PlayerPedId()

    local txd = CreateRuntimeTxd(SafeCracker.Config.TextureDict)
    for i = 1, 2 do
        CreateRuntimeTextureFromImage(txd, tostring(i), "LockPart"..i..".PNG")
    end
    CreateRuntimeTextureFromImage(txd, "lock", "lock.png")
    CreateRuntimeTextureFromImage(txd, "unlock", "unlock.png")

    loadAnimDict("mini@safe_cracking")
    TaskPlayAnim(ped, "mini@safe_cracking", "dial_turn_anti_fast_1", 3.0, 3.0, -1, 49, 0, 0, 0, 0)
    FreezeEntityPosition(ped, true)

    SafeCracker.SoundID = GetSoundId()
    if not RequestAmbientAudioBank(SafeCracker.Config.AudioBank, false) then
        RequestAmbientAudioBank(SafeCracker.Config.AudioBankName, false)
    end

    if not HasStreamedTextureDictLoaded(SafeCracker.Config.TextureDict) then
        RequestStreamedTextureDict(SafeCracker.Config.TextureDict)
    end

    SafeCracker.MinigameOpen = true
    SafeCracker.Timer = GetGameTimer()
    SafeCracker.Callback = cb
    SafeCracker.LockRotation = 0.0

    CreateThread(function()
        Update(combo)
    end)
end

function Update(combo)
    CreateThread(function() HandleMinigame(combo) end)
    while SafeCracker.MinigameOpen do
        InputCheck()
        if IsEntityDead(PlayerPedId()) then EndMinigame(false) end
        Wait(0)
    end
end

local rotatingLeft = false
local rotatingRight = false
local rotationSpeed = 2.0
local singleStep = 1.0

function InputCheck()
    local leftPressed = IsControlJustPressed(0, 174)
    local rightPressed = IsControlJustPressed(0, 175)
    local leftReleased = IsControlJustReleased(0, 174)
    local rightReleased = IsControlJustReleased(0, 175)
    local shift = IsControlPressed(0, 21)

    if IsControlPressed(0, 322) then
        EndMinigame(false)
        return
    end

    if shift then
        if leftPressed then rotatingLeft = true end
        if rightPressed then rotatingRight = true end

        if leftReleased then rotatingLeft = false end
        if rightReleased then rotatingRight = false end

        if rotatingLeft then 
            SafeCracker.LockRotation = SafeCracker.LockRotation - rotationSpeed
            PlaySoundFrontend(0, SafeCracker.Config.SafeTurnSound, SafeCracker.Config.SafeSoundset, false)
        end
        if rotatingRight then
            SafeCracker.LockRotation = SafeCracker.LockRotation + rotationSpeed
            PlaySoundFrontend(0, SafeCracker.Config.SafeTurnSound, SafeCracker.Config.SafeSoundset, false)
        end
    else
        if leftPressed then
            SafeCracker.LockRotation = SafeCracker.LockRotation - singleStep
            PlaySoundFrontend(0, SafeCracker.Config.SafeTurnSound, SafeCracker.Config.SafeSoundset, false)
        end
        if rightPressed then
            SafeCracker.LockRotation = SafeCracker.LockRotation + singleStep
            PlaySoundFrontend(0, SafeCracker.Config.SafeTurnSound, SafeCracker.Config.SafeSoundset, false)
        end
    end
end

function HandleMinigame(combo)
    local lockNumbers = combo
    local correctGuesses = {}
    local correctCount = 1

    local lockRot = lockNumbers[1] <= 149 and math.random(150, 359) or math.random(1, 149)
    SafeCracker.LockRotation = lockRot

    while SafeCracker.MinigameOpen do
        DrawSprite(SafeCracker.Config.TextureDict, "1", 0.8, 0.5, 0.15, 0.26, -SafeCracker.LockRotation, 255, 255, 255, 255)
        DrawSprite(SafeCracker.Config.TextureDict, "2", 0.8, 0.5, 0.176, 0.306, 0.0, 255, 255, 255, 255)

        local lockVal = math.floor(SafeCracker.LockRotation)
        local tolerance = SafeCracker.Config.LockTolerance
        local shift = IsControlPressed(0, 21)

        local startX = 0.76
        local startY = 0.7
        local spacing = 0.04
        for i = 1, #lockNumbers do
            local img = correctGuesses[i] and "unlock" or "lock"
            DrawSprite(SafeCracker.Config.TextureDict, img, startX + (i-1)*spacing, startY, 0.04, 0.07, 0.0, 255, 255, 255, 255)
        end

        for k,v in pairs(lockNumbers) do
            local dist = math.abs(lockVal - v)

            if dist <= SafeCracker.Config.LockTolerance and correctCount == k and not correctGuesses[k] then
                if shift then
                    PlaySoundFrontend(-1, SafeCracker.Config.SafePinSound, SafeCracker.Config.SafeSoundset, true)
                else
                    PlaySoundFrontend(-1, SafeCracker.Config.SafePinSound, SafeCracker.Config.SafeSoundset, true)
                    correctGuesses[k] = lockVal
                    correctCount = correctCount + 1
                end
            end
        end

        if correctCount > #lockNumbers then
            EndMinigame(true)
        end

        Wait(0)
    end
end

function EndMinigame(won)
    if not SafeCracker.MinigameOpen then return end

    SafeCracker.MinigameOpen = false

    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasksImmediately(PlayerPedId())

    if won then
        PlaySoundFrontend(SafeCracker.SoundID, SafeCracker.Config.SafeFinalSound, SafeCracker.Config.SafeSoundset, true)
    end

    if SafeCracker.Callback then
        SafeCracker.Callback(won)
        SafeCracker.Callback = nil
    end
end

function loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(5)
    end
end
