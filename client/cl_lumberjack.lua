local Config = require 'config'
local LumberjackConfig = Config.Lumberjack

local busy = false          -- lagi nebang / lagi proses potong kayu
local currentTreeIndex = nil
local currentSawmillIndex = nil
local sawmillInsufficientNotified = false

local localTreeCooldowns = {}

local function notify(message, messageType)
    exports.qbx_core:Notify(
        message,
        messageType or 'inform'
    )
end

-- =========================================================
-- SETUP POLYZONE (ox_lib zones) UNTUK SETIAP POHON
-- =========================================================

for index, coords in ipairs(LumberjackConfig.trees) do

    lib.zones.sphere({
        coords = coords,
        radius = LumberjackConfig.treeRadius,
        debug = false,

        onEnter = function()
            currentTreeIndex = index
        end,

        onExit = function()
            if currentTreeIndex == index then
                currentTreeIndex = nil
            end
        end,
    })

end

-- =========================================================
-- SETUP POLYZONE UNTUK SAWMILL (TEMPAT POTONG KAYU)
-- =========================================================

for index, coords in ipairs(LumberjackConfig.sawmills) do

    lib.zones.sphere({
        coords = coords,
        radius = LumberjackConfig.sawmillRadius,
        debug = false,

        onEnter = function()
            currentSawmillIndex = index
        end,

        onExit = function()
            if currentSawmillIndex == index then
                currentSawmillIndex = nil
                sawmillInsufficientNotified = false
            end
        end,
    })

end

-- =========================================================
-- NEBANG POHON
-- =========================================================

local function chopTree(index)
    if busy then
        return
    end

    local readyAt = localTreeCooldowns[index]

    if readyAt and readyAt > GetGameTimer() then

        local remaining = math.ceil(
            (readyAt - GetGameTimer()) / 1000
        )

        return notify(
            ('Pohon ini sudah kamu tebang. Tunggu %d detik.'):format(
                remaining
            ),
            'error'
        )
    end

    local available, unavailableMessage = lib.callback.await(
        'zhr_lumberjack:server:canChop',
        false,
        index
    )

    if not available then
        return notify(
            unavailableMessage or 'Pohon ini tidak bisa ditebang sekarang.',
            'error'
        )
    end

    busy = true
    lib.hideTextUI()

    local completed = lib.progressBar({
        duration = math.random(
            LumberjackConfig.choppingDuration.min,
            LumberjackConfig.choppingDuration.max
        ),

        label = 'Menebang pohon...',

        useWhileDead = false,
        canCancel = true,

        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        },

        anim = {
            dict = LumberjackConfig.chopAnim.dict,
            clip = LumberjackConfig.chopAnim.clip,
        },
    })

    if not completed then
        busy = false
        return notify('Menebang dibatalkan.', 'error')
    end

    local success, amount, message = lib.callback.await(
        'zhr_lumberjack:server:chop',
        false,
        index
    )

    busy = false

    localTreeCooldowns[index] =
        GetGameTimer() +
        (LumberjackConfig.cooldownSeconds * 1000)

    if not success then
        return notify(
            message or 'Gagal menebang pohon.',
            'error'
        )
    end

    notify(
        ('Kamu mendapatkan %dx %s.'):format(
            amount,
            LumberjackConfig.logItem.label
        ),
        'success'
    )
end

-- =========================================================
-- PROSES PEMOTONGAN BATANG KAYU JADI POTONGAN KAYU
-- =========================================================

local function processWood()
    if busy then
        return
    end

    local available, unavailableMessage = lib.callback.await(
        'zhr_lumberjack:server:canProcess',
        false
    )

    if not available then
        return notify(
            unavailableMessage or 'Kamu belum bisa memproses batang kayu.',
            'error'
        )
    end

    busy = true
    lib.hideTextUI()

    local completed = lib.progressBar({
        duration = math.random(
            LumberjackConfig.processing.duration.min,
            LumberjackConfig.processing.duration.max
        ),

        label = LumberjackConfig.processing.label,

        useWhileDead = false,
        canCancel = true,

        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        },

        anim = {
            dict = LumberjackConfig.processAnim.dict,
            clip = LumberjackConfig.processAnim.clip,
        },
    })

    if not completed then
        busy = false
        return notify('Proses pemotongan dibatalkan.', 'error')
    end

    local success, produced, message = lib.callback.await(
        'zhr_lumberjack:server:process',
        false
    )

    busy = false

    if not success then
        return notify(
            message or 'Gagal memproses batang kayu.',
            'error'
        )
    end

    notify(
        ('Kamu mendapatkan %dx %s.'):format(
            produced,
            LumberjackConfig.plankItem.label
        ),
        'success'
    )
end

-- =========================================================
-- LOOP INTERAKSI [E]
-- =========================================================

CreateThread(function()

    while true do

        local sleep = 500

        if not busy then

            if currentTreeIndex then

                sleep = 0

                lib.showTextUI(
                    ('[E] %s'):format(LumberjackConfig.targetLabelChop),
                    { position = 'right-center' }
                )

                if IsControlJustReleased(0, 38) then
                    lib.hideTextUI()
                    chopTree(currentTreeIndex)
                end

            elseif currentSawmillIndex then

                sleep = 0

                local required = LumberjackConfig.processing.requiredLogs

                local logCount = exports.ox_inventory:GetItemCount(
                    LumberjackConfig.logItem.name
                ) or 0

                if logCount >= required then

                    sawmillInsufficientNotified = false

                    lib.showTextUI(
                        ('[E] %s'):format(LumberjackConfig.targetLabelProcess),
                        { position = 'right-center' }
                    )

                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        processWood()
                    end

                else

                    lib.hideTextUI()

                    if not sawmillInsufficientNotified then

                        sawmillInsufficientNotified = true

                        notify(
                            ('Butuh %dx %s untuk memotong. Kamu punya %dx.'):format(
                                required,
                                LumberjackConfig.logItem.label,
                                logCount
                            ),
                            'error'
                        )
                    end
                end

            else
                lib.hideTextUI()
            end

        else
            sleep = 200
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    for _, coord in ipairs(LumberjackConfig.trees) do

        local blip = AddBlipForCoord(
            coord.x,
            coord.y,
            coord.z
        )

        SetBlipSprite(blip, 238) -- 🌲 Icon pohon
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 1.0)
        SetBlipColour(blip, 2) -- Hijau
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Lokasi Pohon")
        EndTextCommandSetBlipName(blip)

    end
end)