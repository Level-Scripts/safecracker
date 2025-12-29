function StartMinigame(combo, cb)
    local ped = PlayerPedId()

    local txd = CreateRuntimeTxd(SafeCracker.Config.TextureDict)
    for i = 1, 2 do
        CreateRuntimeTextureFromImage(txd, tostring(i), "LockPart" .. i .. ".PNG")
    end

    loadAnimDict("mini@safe_cracking")
    TaskPlayAnim(ped, "mini@safe_cracking", "dial_turn_anti_fast_1", 3.0, 3.0, -1, 49, 0, 0, 0, 0)

    FreezeEntityPosition(ped, true)

    SafeCracker.MinigameOpen = true
    SafeCracker.SoundID = GetSoundId()
    SafeCracker.Timer = GetGameTimer()
    SafeCracker.Callback = cb

    if not HasStreamedTextureDictLoaded(SafeCracker.Config.TextureDict) then
        RequestStreamedTextureDict(SafeCracker.Config.TextureDict)
    end

    CreateThread(function()
        Update(combo)
    end)
end

exports('StartMinigame', function(combo)
	if SafeCracker.MinigameOpen then
    	return false
	end
    local p = promise.new()

    StartMinigame(combo, function(success)
        p:resolve(success)
    end)

    return Citizen.Await(p)
end)

function Update(combo)
	CreateThread(function() HandleMinigame(combo); end)
	while SafeCracker.MinigameOpen do
		InputCheck()  
		if IsEntityDead(PlayerPedId()) then EndMinigame(false, false); end
		Wait(0)
	end
end

function InputCheck()
    local leftKeyPressed = IsControlPressed( 0, 174) or 0 -- Left
    local rightKeyPressed = IsControlPressed( 0, 175) or 0 -- Right
    if IsControlPressed( 0, 322) then -- Esc
        EndMinigame(false)
    end
    if IsControlPressed( 0, 20) then -- Z
        rotSpeed = 0.1
        modifier = 33
    elseif IsControlPressed( 0, 21) then -- Left Shift
        rotSpeed = 1.0
        modifier = 50
    else
        rotSpeed = 0.4
        modifier = 90
    end
	
    local lockRotation = math.max(modifier / rotSpeed, 0.1)

	if leftKeyPressed ~= 0 or rightKeyPressed ~= 0 then
		
    	SafeCracker.LockRotation = SafeCracker.LockRotation - ( rotSpeed * tonumber( leftKeyPressed ) )
    	SafeCracker.LockRotation = SafeCracker.LockRotation + ( rotSpeed * tonumber( rightKeyPressed ) )
    	if (GetGameTimer() - SafeCracker.Timer) > lockRotation then 
    		PlaySoundFrontend(0, SafeCracker.Config.SafeTurnSound, SafeCracker.Config.SafeSoundset, false)
    		SafeCracker.Timer = GetGameTimer() 
    	end
    end
end

function HandleMinigame(combo) 
	local lockNumbers 	 = {}
	local correctGuesses = {}
	lockNumbers = combo
	if lockNumbers[1] <= 149 then
		lockRot = math.random(150, 359)
	else
		lockRot = math.random(1, 149)
	end

    local correctCount	= 1
    local hasRandomized	= false

    SafeCracker.LockRotation = 0.0 + lockRot
	while SafeCracker.MinigameOpen do	
		--Texture Dictionary, Texture Name, xPos, yPos, xSize, ySize, 		   Heading,   R,   G,   B,   A,
		DrawSprite(SafeCracker.Config.TextureDict, 		 "1",  0.8,  0.5,  0.15,  0.26, -SafeCracker.LockRotation, 255, 255, 255, 255)
		DrawSprite(SafeCracker.Config.TextureDict, 		 "2",  0.8,  0.5, 0.176, 0.306, 		      -0.0, 255, 255, 255, 255)	

		hasRandomized = true

		local lockVal = math.floor(SafeCracker.LockRotation)

		if correctCount > 1 and correctCount < (#lockNumbers + 1) and lockVal + (SafeCracker.Config.LockTolerance * 3.60) < lockNumbers[correctCount - 1] and lockNumbers[correctCount - 1] < lockNumbers[correctCount] then EndMinigame(false); SafeCracker.MinigameOpen = false; 
		elseif correctCount > 1 and correctCount < (#lockNumbers + 1) and lockVal - (SafeCracker.Config.LockTolerance * 3.60) > lockNumbers[correctCount - 1] and lockNumbers[correctCount - 1] > lockNumbers[correctCount] then EndMinigame(false); SafeCracker.MinigameOpen = false; 
		elseif correctCount > #lockNumbers then EndMinigame(true)
		end

		for k,v in pairs(lockNumbers) do
			if not hasRandomized then SafeCracker.LockRotation = lockRot; end
			if lockVal == v and correctCount == k then
				local canAdd = true
				for key,val in pairs(correctGuesses) do
					if val == lockVal and key == correctCount then
						canAdd = false
					end
				end

				if canAdd then 				
					PlaySoundFrontend(-1, SafeCracker.Config.SafePinSound, SafeCracker.Config.SafeSoundset, true)
					correctGuesses[correctCount] = lockVal
					correctCount = correctCount + 1; 
				end   				  			
			end
		end
		Wait(0)
	end
end

function EndMinigame(won)
    if not SafeCracker.MinigameOpen then return end

    SafeCracker.MinigameOpen = false

    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasksImmediately(PlayerPedId())

    if SafeCracker.Callback then
        SafeCracker.Callback(won)
        SafeCracker.Callback = nil
    end
end

RegisterNetEvent('SafeCracker:EndGame', function()
	EndMinigame();
end)

function loadAnimDict( dict )
    while ( not HasAnimDictLoaded( dict ) ) do
        RequestAnimDict( dict )
        Wait( 5 )
    end
end 
