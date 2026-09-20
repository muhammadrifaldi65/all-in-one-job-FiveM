local Config = require 'config'
local ShopConfig = Config.Shop



local TREASURY_KEY = 'zhr_disnaker_treasury'

local function getTreasury()
    local value = GetResourceKvpInt(TREASURY_KEY)
    return value or 0
end

local function setTreasury(value)

    if value < 0 then
        value = 0
    end

    SetResourceKvpInt(TREASURY_KEY, value)

    -- broadcast biar UI yang lagi kebuka update saldo real-time
    TriggerClientEvent('zhr_shop:client:treasuryUpdated', -1, value)
end


-- HELPER: item dari config berdasarkan nama


local function getShopItem(itemName)

    for _, entry in ipairs(ShopConfig.items) do
        if entry.item == itemName then
            return entry
        end
    end

    return nil
end


-- HELPER: cek jarak player ke salah satu lokasi toko


local function playerIsNearShop(source)
    local ped = GetPlayerPed(source)

    if ped == 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)

    for _, coords in ipairs(ShopConfig.locations) do

        if #(playerCoords - coords) <= (ShopConfig.interactionDistance + 2.0) then
            return true
        end
    end

    return false
end


-- HELPER: cek apakah source adalah admin / job pengisi dana


local function canManageFunds(source)

    if IsPlayerAceAllowed(source, 'command') then
        return true
    end

    local player = exports.qbx_core:GetPlayer(source)

    if not player then
        return false
    end

    local jobName = player.PlayerData.job and player.PlayerData.job.name

    if not jobName then
        return false
    end

    for _, allowedJob in ipairs(ShopConfig.fundManagerJobs) do
        if jobName == allowedJob then
            return true
        end
    end

    return false
end


-- CALLBACK: ambil daftar item + saldo dana pemerintah
-- (dipanggil client saat buka UI toko)


lib.callback.register(
    'zhr_shop:server:getShopData',
    function(source)

        if not playerIsNearShop(source) then
            return false
        end

        local itemsWithOwned = {}

        for index, entry in ipairs(ShopConfig.items) do

            itemsWithOwned[index] = {
                item = entry.item,
                label = entry.label,
                price = entry.price,
                maxPerSell = entry.maxPerSell,
                owned = exports.ox_inventory:GetItemCount(source, entry.item) or 0,
            }
        end

        return {
            items = itemsWithOwned,
            treasury = getTreasury(),
        }
    end
)


-- CALLBACK: JUAL BARANG


lib.callback.register(
    'zhr_shop:server:sell',
    function(source, itemName, amount)

        amount = tonumber(amount)

        if not amount or amount <= 0 or amount ~= math.floor(amount) then
            return false, 'Jumlah tidak valid.'
        end

        if not playerIsNearShop(source) then
            return false, 'Kamu terlalu jauh dari tempat penjualan.'
        end

        local shopItem = getShopItem(itemName)

        if not shopItem then
            return false, 'Barang ini tidak diterima di sini.'
        end

        if amount > shopItem.maxPerSell then
            return false, (
                'Maksimal %dx %s per transaksi.'
            ):format(shopItem.maxPerSell, shopItem.label)
        end

        local ownedCount = exports.ox_inventory:GetItemCount(source, itemName)

        if ownedCount < amount then
            return false, (
                'Barangmu tidak cukup. Kamu punya %dx %s.'
            ):format(ownedCount, shopItem.label)
        end

        local totalPrice = shopItem.price * amount
        local treasury = getTreasury()

        if treasury < totalPrice then

            if treasury <= 0 then
                return false, 'Dana pemerintah untuk pembelian barang sedang habis. Coba lagi nanti.'
            end

            return false, (
                'Dana pemerintah tidak cukup. Sisa dana hanya bisa membeli senilai Rp%d.'
            ):format(treasury)
        end

        local player = exports.qbx_core:GetPlayer(source)

        if not player then
            return false, 'Data pemain tidak ditemukan.'
        end

        local removed = exports.ox_inventory:RemoveItem(source, itemName, amount)

        if not removed then
            return false, 'Gagal mengambil barang dari inventory.'
        end

        player.Functions.AddMoney(
            ShopConfig.moneyAccount,
            totalPrice,
            'zhr-disnaker-sell'
        )

        setTreasury(treasury - totalPrice)

        return true, totalPrice, getTreasury()
    end
)


-- COMMAND: ISI DANA PEMERINTAH
-- Bisa dipakai admin (ACE 'command') atau job yang
-- terdaftar di Config.Shop.fundManagerJobs


RegisterCommand('disnakerdana', function(source, args)

    if source == 0 then
        -- dijalankan dari console server, selalu diizinkan
    elseif not canManageFunds(source) then

        TriggerClientEvent(
            'ox_lib:notify',
            source,
            {
                description = 'Kamu tidak punya izin untuk mengisi dana ini.',
                type = 'error',
            }
        )

        return
    end

    local amount = tonumber(args[1])

    if not amount or amount <= 0 then

        local message = 'Gunakan: /disnakerdana [jumlah]'

        if source == 0 then
            print(message)
        else
            TriggerClientEvent('ox_lib:notify', source, {
                description = message,
                type = 'error',
            })
        end

        return
    end

    local newTreasury = getTreasury() + math.floor(amount)
    setTreasury(newTreasury)

    local message = ('Dana pemerintah untuk Disnaker bertambah Rp%d. Total sekarang: Rp%d.'):format(
        math.floor(amount),
        newTreasury
    )

    if source == 0 then
        print(message)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            description = message,
            type = 'success',
        })
    end

end, false)


-- COMMAND: CEK SALDO DANA PEMERINTAH


RegisterCommand('disnakersaldo', function(source)

    local message = ('Sisa dana pemerintah Disnaker saat ini: Rp%d.'):format(getTreasury())

    if source == 0 then
        print(message)
        return
    end

    if not canManageFunds(source) then

        TriggerClientEvent('ox_lib:notify', source, {
            description = 'Kamu tidak punya izin untuk melihat ini.',
            type = 'error',
        })

        return
    end

    TriggerClientEvent('ox_lib:notify', source, {
        description = message,
        type = 'inform',
    })

end, false)


-- EXPORTS (biar resource lain bisa isi/cek dana juga kalau perlu)


exports('GetDisnakerTreasury', getTreasury)
exports('AddDisnakerTreasury', function(amount)
    amount = tonumber(amount) or 0
    setTreasury(getTreasury() + amount)
    return getTreasury()
end)
