local Config = require 'config'

local SampahConfig = Config.Sampah

local cooldowns = {}

local function locationKey(coords)
    return ('%.1f:%.1f:%.1f'):format(
        coords.x,
        coords.y,
        coords.z
    )
end

local function validCoords(coords)
    return type(coords) == 'vector3'
        and math.abs(coords.x) < 10000
        and math.abs(coords.y) < 10000
        and coords.z > -100
        and coords.z < 2000
end

local function playerIsNear(source, coords)
    local ped = GetPlayerPed(source)

    if ped == 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)

    return #(playerCoords - coords) <= (
        SampahConfig.interactionDistance + 2.0
    )
end

-- =========================================================
-- CHECK COOLDOWN
-- =========================================================

lib.callback.register(
    'citytrash:server:checkCooldown',
    function(source, coords)

        if not validCoords(coords) then
            return false
        end

        if not playerIsNear(source, coords) then
            return false
        end

        local key = locationKey(coords)
        local readyAt = cooldowns[key]

        return not readyAt or readyAt <= os.time()
    end
)

-- =========================================================
-- RANDOM REWARD BERDASARKAN WEIGHT
-- =========================================================

local function getRandomReward()

    local totalWeight = 0

    for _, reward in ipairs(SampahConfig.rewards) do
        totalWeight += reward.weight
    end

    if totalWeight <= 0 then
        return nil
    end

    local randomValue = math.random(1, totalWeight)
    local currentWeight = 0

    for _, reward in ipairs(SampahConfig.rewards) do

        currentWeight += reward.weight

        if randomValue <= currentWeight then
            return reward
        end
    end

    return nil
end

-- =========================================================
-- SEARCH SAMPAH
-- =========================================================

lib.callback.register(
    'citytrash:server:search',
    function(source, coords)

        if not validCoords(coords) then
            return false, 0, 'Lokasi tidak valid.'
        end

        if not playerIsNear(source, coords) then
            return false, 0, 'Kamu terlalu jauh dari tempat sampah.'
        end

        local key = locationKey(coords)
        local now = os.time()

        local readyAt = cooldowns[key]

        if readyAt and readyAt > now then

            local remaining = readyAt - now

            return false, 0, (
                'Tempat sampah ini masih cooldown %d detik.'
            ):format(remaining)
        end

        -- =============================================
        -- PILIH 1-3 ITEM
        -- =============================================

        local rewardCount = math.random(1, 3)

        local rewards = {}

        for i = 1, rewardCount do

            local reward = getRandomReward()

            if reward then

                local amount = math.random(1, 3)

                rewards[#rewards + 1] = {
                    item = reward.item,
                    label = reward.label,
                    amount = amount
                }

            end
        end

        if #rewards == 0 then
            return false, 0, 'Tidak menemukan apa-apa.'
        end

        -- =============================================
        -- CEK INVENTORY
        -- =============================================

        for _, reward in ipairs(rewards) do

            local canCarry = exports.ox_inventory:CanCarryItem(
                source,
                reward.item,
                reward.amount
            )

            if not canCarry then
                return false, 0,
                    'Inventory kamu tidak cukup untuk membawa hasil pencarian.'
            end
        end

        -- =============================================
        -- MASUKKAN ITEM
        -- =============================================

        for _, reward in ipairs(rewards) do

            local added = exports.ox_inventory:AddItem(
                source,
                reward.item,
                reward.amount
            )

            if not added then
                return false, 0,
                    'Gagal memasukkan hasil pencarian ke inventory.'
            end
        end

        -- =============================================
        -- COOLDOWN
        -- =============================================

        cooldowns[key] = now + SampahConfig.cooldownSeconds

        return rewards
    end
)

-- =========================================================
-- PLAYER DROP
-- =========================================================

AddEventHandler('playerDropped', function()

    -- Cooldown lokasi bersifat global.
    -- Tetap berjalan walaupun pemain disconnect.

end)