local Config = require 'config'
local SampahConfig = Config.Sampah

local localCooldowns = {}
local searching = false

local function locationKey(coords)
    return ('%.1f:%.1f:%.1f'):format(
        coords.x,
        coords.y,
        coords.z
    )
end

local function notify(message, messageType)
    exports.qbx_core:Notify(
        message,
        messageType or 'inform'
    )
end

local function searchBin(entity)
    if searching then
        return
    end

    if not entity or not DoesEntityExist(entity) then
        return
    end

    local coords = GetEntityCoords(entity)
    local key = locationKey(coords)

    local localReadyAt = localCooldowns[key]

    if localReadyAt and localReadyAt > GetGameTimer() then

        local remaining = math.ceil(
            (localReadyAt - GetGameTimer()) / 1000
        )

        return notify(
            ('Tempat sampah ini masih kosong. Tunggu %d detik.'):format(
                remaining
            ),
            'error'
        )
    end

    local available = lib.callback.await(
        'citytrash:server:checkCooldown',
        false,
        coords
    )

    if not available then

        localCooldowns[key] =
            GetGameTimer() +
            (SampahConfig.cooldownSeconds * 1000)

        return notify(
            'Tempat sampah ini sudah dicari orang lain. Coba yang lain.',
            'error'
        )
    end

    searching = true

    local completed = lib.progressBar({
        duration = math.random(
            SampahConfig.searchDuration.min,
            SampahConfig.searchDuration.max
        ),

        label = SampahConfig.searchLabel,

        useWhileDead = false,
        canCancel = true,

        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        },

        anim = {
            dict = 'amb@prop_human_bum_bin@base',
            clip = 'base',
            flag = 49,
        },
    })

    if not completed then

        searching = false

        return notify(
            'Pencarian dibatalkan.',
            'error'
        )
    end

    local rewards, _, message = lib.callback.await(
        'citytrash:server:search',
        false,
        coords
    )

    searching = false

    if not rewards then

        localCooldowns[key] =
            GetGameTimer() +
            (SampahConfig.cooldownSeconds * 1000)

        return notify(
            message or 'Tempat sampah ini sudah kosong.',
            'error'
        )
    end

    localCooldowns[key] =
        GetGameTimer() +
        (SampahConfig.cooldownSeconds * 1000)

    local foundItems = {}

    for _, reward in ipairs(rewards) do

        foundItems[#foundItems + 1] = (
            '%dx %s'
        ):format(
            reward.amount,
            reward.label
        )

    end

    notify(
        ('Kamu menemukan: %s.'):format(
            table.concat(foundItems, ', ')
        ),
        'success'
    )
end

-- =========================================================
-- CARI TEMPAT SAMPAH TERDEKAT
-- =========================================================

local function GetClosestTrashBin()
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    local closestEntity = nil
    local closestDistance = 999.0

    for _, model in ipairs(SampahConfig.binModels) do

        local modelHash = joaat(model)

        local entity = GetClosestObjectOfType(
            playerCoords.x,
            playerCoords.y,
            playerCoords.z,
            SampahConfig.interactionDistance,
            modelHash,
            false,
            false,
            false
        )

        if entity ~= 0 and DoesEntityExist(entity) then

            local entityCoords = GetEntityCoords(entity)

            local distance = #(
                playerCoords - entityCoords
            )

            if distance < closestDistance then
                closestDistance = distance
                closestEntity = entity
            end
        end
    end

    return closestEntity, closestDistance
end

-- =========================================================
-- INTERAKSI E
-- =========================================================

CreateThread(function()

    while true do

        local sleep = 1000

        if not searching then

            local ped = PlayerPedId()

            if not IsEntityDead(ped)
                and not IsPedInAnyVehicle(ped, false)
            then

                local entity, distance =
                    GetClosestTrashBin()

                if entity and distance <= SampahConfig.interactionDistance then

                    sleep = 0

                    lib.showTextUI(
                        '[E] ' .. SampahConfig.targetLabel,
                        {
                            position = 'right-center'
                        }
                    )

                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        searchBin(entity)
                    end

                else
                    lib.hideTextUI()
                end

            else
                lib.hideTextUI()
            end

        else
            sleep = 100
        end

        Wait(sleep)
    end
end)