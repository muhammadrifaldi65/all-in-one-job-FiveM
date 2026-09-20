local Config = require 'config'
local ShopConfig = Config.Shop

local inShopZone = false
local shopOpen = false

local function notify(message, messageType)
    exports.qbx_core:Notify(
        message,
        messageType or 'inform'
    )
end

-- =========================================================
-- SETUP ZONE UNTUK SETIAP LOKASI TOKO
-- =========================================================

for _, coords in ipairs(ShopConfig.locations) do

    lib.zones.sphere({
        coords = coords,
        radius = ShopConfig.interactionDistance,
        debug = false,

        onEnter = function()
            inShopZone = true
        end,

        onExit = function()
            inShopZone = false

            if shopOpen then
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'close' })
                shopOpen = false
            end
        end,
    })

end

-- =========================================================
-- BUKA TOKO
-- =========================================================

local function openShop()

    if shopOpen then
        return
    end

    local data = lib.callback.await('zhr_shop:server:getShopData', false)

    if not data then
        return notify('Kamu terlalu jauh dari tempat penjualan.', 'error')
    end

    shopOpen = true

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        title = ShopConfig.label,
        items = data.items,
        treasury = data.treasury,
    })
end

local function closeShop()
    shopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- =========================================================
-- NUI CALLBACKS
-- =========================================================

RegisterNUICallback('zhr_shop:close', function(_, cb)
    closeShop()
    cb('ok')
end)

RegisterNUICallback('zhr_shop:sell', function(data, cb)

    local success, resultOrMessage, treasury = lib.callback.await(
        'zhr_shop:server:sell',
        false,
        data.item,
        data.amount
    )

    if not success then
        notify(resultOrMessage or 'Gagal menjual barang.', 'error')
        cb({ success = false, message = resultOrMessage })
        return
    end

    notify(
        ('Berhasil menjual barang, kamu dapat Rp%d.'):format(resultOrMessage),
        'success'
    )

    cb({ success = true, earned = resultOrMessage, treasury = treasury })
end)

-- =========================================================
-- UPDATE SALDO SECARA REAL-TIME (kalau admin isi dana
-- sementara UI toko sedang terbuka)
-- =========================================================

RegisterNetEvent('zhr_shop:client:treasuryUpdated', function(newTreasury)

    if shopOpen then
        SendNUIMessage({
            action = 'updateTreasury',
            treasury = newTreasury,
        })
    end
end)

-- =========================================================
-- LOOP INTERAKSI [E]
-- =========================================================

CreateThread(function()

    while true do

        local sleep = 500

        if inShopZone and not shopOpen then

            sleep = 0

            lib.showTextUI(
                ('[E] %s'):format(ShopConfig.targetLabel),
                { position = 'right-center' }
            )

            if IsControlJustReleased(0, 38) then
                lib.hideTextUI()
                openShop()
            end

        else
            lib.hideTextUI()
        end

        Wait(sleep)
    end
end)

-- =========================================================
-- ESC UNTUK MENUTUP UI TOKO
-- =========================================================

CreateThread(function()

    while true do

        if shopOpen then

            if IsControlJustReleased(0, 322) then -- ESC / backspace
                closeShop()
            end

            Wait(0)
        else
            Wait(250)
        end
    end




end)
CreateThread(function()
    local blip = AddBlipForCoord(-568.8146, 5237.7017, 70.4695)

    SetBlipSprite(blip, 280)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Loket Disnaker")
    EndTextCommandSetBlipName(blip)
end)