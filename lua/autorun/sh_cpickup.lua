local ENTITY, PLAYER = FindMetaTable("Entity"), FindMetaTable("Player")
local eEyePos = ENTITY.EyePos
local pGetAimVector = PLAYER.GetAimVector

local function FindUseEntity(ply)
    local eyePos = eEyePos(ply)
    local trData = util.TraceLine({
        start = eyePos,
        endpos = eyePos + pGetAimVector(ply) * 80,
        filter = ply
    })

    return trData.Entity
end

local enabled = CreateConVar("cl_cpickup", 1, bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "", 0, 1)
local shouldEquip = nil
local shouldAnimate = nil

if CLIENT then
    shouldEquip = CreateClientConVar("cl_cpickup_alwaysequip", 1, true, false, "", 0, 1)
    shouldAnimate = CreateClientConVar("cl_cpickup_vmanip", 0, true, false, "", 0, 1)
end

local isCallingPickupHooks = false

hook.Add("KeyPress", "CPickup.DoPickup", function(ply, key)
    if !enabled:GetBool() or key != IN_USE then
        return
    end

    local useEntity = FindUseEntity(ply)

    if !IsValid(useEntity) or !useEntity:IsValid() or !useEntity:IsWeapon() then
        return
    end

    local wepClass = useEntity:GetClass()

    isCallingPickupHooks = true

    local canPickup = true

    if SERVER then
        canPickup = hook.Run("PlayerCanPickupWeapon", ply, useEntity)
    end

    isCallingPickupHooks = false

    if SERVER and canPickup == false then
        return
    end

    if SERVER then
        local ammoOnly = ply:HasWeapon(wepClass) and true or false

        ply:PickupWeapon(useEntity, ammoOnly)

        return
    end

    if !IsFirstTimePredicted() then
        return
    end

    timer.Simple(0, function()
        if !IsValid(ply) or !IsValid(useEntity) or !ply:HasWeapon(wepClass) then
            return
        end

        local timerDuration = 0

        if shouldAnimate:GetBool() and VManip and !VManip:IsActive() then
            VManip:PlayAnim("interactslower")

            timerDuration = VManip.Duration
        end

        if !shouldEquip:GetBool() then
            return
        end

        if timerDuration != 0 then
            timer.Simple(timerDuration, function()
                if !IsValid(ply) or !IsValid(useEntity) then
                    return
                end

                input.SelectWeapon(useEntity)
            end)
        else
            input.SelectWeapon(useEntity)
        end
    end)
end)

if SERVER then
    hook.Add("PlayerCanPickupWeapon", "CPickup.StopDefaultPickup", function(ply, wep)
        if isCallingPickupHooks or !enabled:GetBool() then
            return
        end

        if wep.SpawnedIn then
            return true
        end

        return false
    end)

    hook.Add("AllowPlayerPickup", "CPickup.StopPhysicsPickup", function(ply, ent)
        if enabled:GetBool() and ent:IsWeapon() then
            return false
        end
    end)

    hook.Add("OnEntityCreated", "CPickup.HandleSpawnMenu", function(ent)
        if enabled:GetBool() and ent:IsWeapon() then
            ent.SpawnedIn = true

            timer.Simple(0, function()
                if !IsValid(ent) then
                    return
                end

                ent.SpawnedIn = false
            end)
        end
    end)
end

if CLIENT then
    local scale = ScrW() / 2560

    surface.CreateFont("CPickup.Main", {
        font = system.IsLinux() and "stratum2-medium.ttf" or "Stratum2 Md",
        extended = true,
        size = math.Round(28 * scale),
        weight = 500
    })

    surface.CreateFont("CPickup.Alt", {
        font = system.IsLinux() and "stratum2-bold.ttf" or "Stratum2 Bd",
        extended = true,
        size = math.Round(28 * scale),
        weight = 500
    })

    local hudEnabled = CreateClientConVar("cl_cpickup_hud", 0, true, false, "", 0, 1)
    local bindFormat = "[%s] pickup "
    local pickupAlpha, lastWep = 0, nil

    hook.Add("HUDPaint", "CPickup.DrawNotice", function()
        if !enabled:GetBool() or !hudEnabled:GetBool() then
            return
        end

        local useWep = FindUseEntity(LocalPlayer())
        local curWep = useWep

        if !IsValid(curWep) or !curWep:IsWeapon() then
            pickupAlpha = math.Approach(pickupAlpha, 0, RealFrameTime() / 0.1)

            curWep = lastWep
        else
            pickupAlpha = math.Approach(pickupAlpha, 1, RealFrameTime() / 0.1)
        end

        -- Check again to enforce last weapon validity.
        if !IsValid(curWep) or !curWep:IsWeapon() then
            return
        end

        -- Don't waste resources drawing an invisible pickup notice.
        if !IsValid(useWep) and pickupAlpha == 0 then
            return
        end

        local y = ((ScrH() * 0.54) + 32) - 32 * pickupAlpha
        local useKey = input.LookupBinding("+use", true) or "NONE"
        local bindText = string.format(bindFormat, string.upper(useKey))

        surface.SetFont("CPickup.Main")

        local kWidth, _ = surface.GetTextSize(bindText)
        local wepName = language.GetPhrase(curWep:GetPrintName()) or curWep:GetPrintName()

        surface.SetFont("CPickup.Alt")

        local wWidth, _ = surface.GetTextSize(wepName)
        local x = ScrW() * 0.5 - (kWidth + wWidth) * 0.5

        surface.SetFont("CPickup.Main")
        surface.SetTextPos(x, y)
        surface.SetTextColor(255, 255, 255, 100 * pickupAlpha)
        surface.DrawText(bindText)

        local wepName = language.GetPhrase(curWep:GetPrintName()) or curWep:GetPrintName()

        surface.SetFont("CPickup.Alt")
        surface.SetTextPos(x + kWidth, y)
        surface.SetTextColor(255, 255, 255, 255 * pickupAlpha)
        surface.DrawText(wepName)

        lastWep = curWep
    end)
end