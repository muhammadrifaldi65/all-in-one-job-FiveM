local Config = require 'config'
local LumberjackConfig = Config.Lumberjack

-- cooldowns[treeIndex] = timestamp (os.time()) kapan pohon itu bisa ditebang lagi
local cooldowns = {}

local function playerIsNearCoords(source, coords, radius)
    local ped = GetPlayerPed(source)

    if ped == 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)

    return #(playerCoords - coords) <= (radius + 2.0)
end

local function playerIsNearAnySawmill(source)
    for _, coords in ipairs(LumberjackConfig.sawmills) do

        if playerIsNearCoords(source, coords, LumberjackConfig.sawmillRadius) then
            return true
        end

    end

    return false
end

-- =========================================================
-- CEK APAKAH POHON BISA DITEBANG (cooldown + kapasitas inventory)
-- Dipanggil client SEBELUM animasi/progressbar dimulai
-- =========================================================

local function canChopTree(source, index)

    local treeCoords = LumberjackConfig.trees[index]

    if not treeCoords then
        return false, 'Pohon tidak valid.'
    end

    if not playerIsNearCoords(source, treeCoords, LumberjackConfig.treeRadius) then
        return false, 'Kamu terlalu jauh dari pohon.'
    end

    local now = os.time()
    local readyAt = cooldowns[index]

    if readyAt and readyAt > now then

        local remaining = readyAt - now

        return false, (
            'Pohon ini masih cooldown %d detik.'
        ):format(remaining)
    end

    -- Cek kapasitas pakai jumlah maksimal (worst case),
    -- biar animasi gak jalan kalau ujung-ujungnya pasti gagal
    local canCarry = exports.ox_inventory:CanCarryItem(
        source,
        LumberjackConfig.logItem.name,
        LumberjackConfig.chopReward.max
    )

    if not canCarry then
        return false, 'Inventory kamu tidak cukup untuk membawa batang kayu.'
    end

    return true
end

lib.callback.register(
    'zhr_lumberjack:server:canChop',
    function(source, index)
        return canChopTree(source, index)
    end
)

-- =========================================================
-- TEBANG POHON -> DAPAT BATANG KAYU (ACAK 1-5)
-- =========================================================

lib.callback.register(
    'zhr_lumberjack:server:chop',
    function(source, index)

        -- Validasi ulang di sini (jangan percaya hasil precheck client)
        local canChop, chopMessage = canChopTree(source, index)

        if not canChop then
            return false, 0, chopMessage
        end

        local now = os.time()

        -- =============================================
        -- JUMLAH BATANG KAYU ACAK 1-5
        -- =============================================

        local amount = math.random(
            LumberjackConfig.chopReward.min,
            LumberjackConfig.chopReward.max
        )

        local canCarry = exports.ox_inventory:CanCarryItem(
            source,
            LumberjackConfig.logItem.name,
            amount
        )

        if not canCarry then
            return false, 0,
                'Inventory kamu tidak cukup untuk membawa batang kayu.'
        end

        local added = exports.ox_inventory:AddItem(
            source,
            LumberjackConfig.logItem.name,
            amount
        )

        if not added then
            return false, 0,
                'Gagal memasukkan batang kayu ke inventory.'
        end

        -- =============================================
        -- COOLDOWN POHON
        -- =============================================

        cooldowns[index] = now + LumberjackConfig.cooldownSeconds

        return true, amount
    end
)

-- =========================================================
-- CEK APAKAH BISA MEMPROSES KAYU (jumlah log + kapasitas hasil)
-- Dipanggil client SEBELUM animasi/progressbar dimulai
-- =========================================================

local function canProcessWood(source)

    if not playerIsNearAnySawmill(source) then
        return false, 'Kamu terlalu jauh dari tempat pemotongan kayu.'
    end

    local required = LumberjackConfig.processing.requiredLogs
    local produced = LumberjackConfig.processing.producedPlanks

    local logCount = exports.ox_inventory:GetItemCount(
        source,
        LumberjackConfig.logItem.name
    )

    if logCount < required then
        return false, (
            'Batang kayu tidak cukup. Butuh %dx %s.'
        ):format(required, LumberjackConfig.logItem.label)
    end

    local canCarry = exports.ox_inventory:CanCarryItem(
        source,
        LumberjackConfig.plankItem.name,
        produced
    )

    if not canCarry then
        return false, 'Inventory kamu tidak cukup untuk membawa potongan kayu.'
    end

    return true
end

lib.callback.register(
    'zhr_lumberjack:server:canProcess',
    function(source)
        return canProcessWood(source)
    end
)

-- =========================================================
-- PROSES PEMOTONGAN: 10 BATANG KAYU -> 10 POTONGAN KAYU
-- =========================================================

lib.callback.register(
    'zhr_lumberjack:server:process',
    function(source)

        -- Validasi ulang di sini (jangan percaya hasil precheck client)
        local canProcess, processMessage = canProcessWood(source)

        if not canProcess then
            return false, 0, processMessage
        end

        local required = LumberjackConfig.processing.requiredLogs
        local produced = LumberjackConfig.processing.producedPlanks

        -- =============================================
        -- REMOVE BATANG KAYU
        -- =============================================

        local removed = exports.ox_inventory:RemoveItem(
            source,
            LumberjackConfig.logItem.name,
            required
        )

        if not removed then
            return false, 0,
                'Gagal mengambil batang kayu dari inventory.'
        end

        -- =============================================
        -- TAMBAHKAN POTONGAN KAYU
        -- =============================================

        local added = exports.ox_inventory:AddItem(
            source,
            LumberjackConfig.plankItem.name,
            produced
        )

        if not added then

            -- rollback batang kayu jika gagal menambahkan hasil
            exports.ox_inventory:AddItem(
                source,
                LumberjackConfig.logItem.name,
                required
            )

            return false, 0,
                'Gagal memproses batang kayu.'
        end

        return true, produced
    end
)

-- =========================================================
-- PLAYER DROP
-- =========================================================

AddEventHandler('playerDropped', function()

    -- Cooldown pohon bersifat global.
    -- Tetap berjalan walaupun pemain disconnect.

end)