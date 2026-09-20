local Config = {}



Config.Sampah = {

    cooldownSeconds = 120,

    searchDuration = {
        min = 4500,
        max = 6500
    },

    interactionDistance = 2.0,

    searchLabel = 'Mencari barang di tempat sampah',

    targetLabel = 'Cari tempat sampah',

    targetIcon = 'fa-solid fa-trash-can',

    -- Weight menentukan peluang item terpilih.
    -- Jumlah item tetap 1-3.
    rewards = {
        {
            item = 'botol',
            label = 'Botol',
            weight = 30
        },

        {
            item = 'kaca',
            label = 'Kaca',
            weight = 20
        },

        {
            item = 'karung',
            label = 'Karung',
            weight = 15
        },

        {
            item = 'plastik',
            label = 'Plastik',
            weight = 25
        },

        {
            item = 'metalscrap',
            label = 'Metal Scrap',
            weight = 10
        },
    },

    -- Model tempat sampah publik dan dumpster GTA V
    binModels = {
        'prop_dumpster_01a',
        'prop_dumpster_02a',
        'prop_dumpster_02b',
        'prop_dumpster_3a',
        'prop_dumpster_4a',
        'prop_dumpster_4b',

        'prop_bin_01a',
        'prop_bin_02a',
        'prop_bin_03a',
        'prop_bin_04a',
        'prop_bin_05a',
        'prop_bin_06a',
        'prop_bin_07a',
        'prop_bin_07b',
        'prop_bin_07c',
        'prop_bin_07d',
        'prop_bin_08a',
        'prop_bin_08open',
        'prop_bin_09a',
        'prop_bin_10a',
        'prop_bin_11a',
        'prop_bin_12a',
        'prop_bin_13a',
    }
}



Config.Lumberjack = {

    -- Radius zone (polyzone) di sekitar tiap pohon & sawmill
    treeRadius = 1.2,
    sawmillRadius = 1.5,

    -- Cooldown per pohon setelah ditebang (detik)
    cooldownSeconds = 120,

    -- Berapa batang kayu didapat sekali nebang (acak min-max)
    chopReward = {
        min = 1,
        max = 5
    },

    -- Durasi progress bar nebang (ms)
    choppingDuration = {
        min = 5000,
        max = 8000
    },

    -- Item batang kayu (hasil nebang)
    logItem = {
        name = 'kayu_batang',
        label = 'Batang Kayu'
    },

    -- Item potongan kayu (hasil proses pemotongan)
    plankItem = {
        name = 'kayu_potongan',
        label = 'Potongan Kayu'
    },

    -- Proses pemotongan: butuh X batang kayu, hasilkan Y potongan kayu
    processing = {
        requiredLogs = 10,
        producedPlanks = 10,

        duration = {
            min = 8000,
            max = 12000
        },

        label = 'Memotong batang kayu'
    },

    -- Animasi nebang pohon
    chopAnim = {
        dict = 'melee@hatchet@streamed_core',
        clip = 'plyr_front_takedown'
    },


    -- Animasi proses pemotongan kayu (di sawmill)
    processAnim = {
        dict = 'mini@repair',
        clip = 'fixing_a_ped'
    },

    targetLabelChop = 'Tebang pohon',
    targetLabelProcess = 'Potong batang kayu',

   
    -- KOORDINAT SETIAP POHON

trees = {
    vector3(-605.0244, 5243.9072, 71.5011),
    vector3(-601.1753, 5240.1123, 71.5646),
    vector3(-643.6802, 5241.7930, 75.2217),
    vector3(-645.0723, 5270.0815, 73.4346),
    vector3(-633.9770, 5274.8433, 69.3376),
    vector3(-628.1913, 5284.9062, 64.1171),
    vector3(-639.4150, 5279.1421, 69.4768),
    vector3(-647.8609, 5278.7378, 71.6281),
    vector3(-626.6113, 5314.9878, 59.9715),
    vector3(-628.0610, 5322.0444, 59.5441),
    vector3(-643.1785, 5297.0894, 66.3792),
    vector3(-656.7093, 5296.9907, 68.8659),
    vector3(-658.1335, 5293.7319, 69.9245),
    vector3(-664.2123, 5278.9766, 74.0139),
    vector3(-690.0963, 5304.0532, 69.9901),
    vector3(-711.2571, 5272.9126, 74.8944),
    vector3(-717.0420, 5272.4526, 76.5520),
    vector3(-557.9153, 5234.3296, 71.7862),
    vector3(-558.9247, 5224.8389, 76.3271),
    vector3(-547.3039, 5220.2012, 77.7684),
    vector3(-537.1411, 5226.9961, 78.3497),
},

  
    -- KOORDINAT TEMPAT PROSES PEMOTONGAN KAYU 
  
    sawmills = {
        vector3(-567.3620, 5253.0605, 70.4700),
    }
}



Config.Shop = {

  
    -- TEMPAT PENJUALAN BARANG (DISNAKER)
    -- Warga jual barang di sini, uangnya diambil dari
    -- "dana pemerintah" yang diisi admin / job tertentu.
    -- Kalau dana habis, warga gak bisa jual sampai diisi lagi.
  

    label = 'Tempat Penjualan Barang - Disnaker',

    interactionDistance = 2.0,

    targetLabel = 'Buka toko penjualan',
    targetIcon = 'fa-solid fa-coins',

    -- Titik lokasi tempat jualan (bisa lebih dari satu)
    locations = {
        vector3(-568.8146, 5237.7017, 70.4695),
    },

    -- Uang yang didapat warga masuk ke cash/bank
    moneyAccount = 'cash', -- 'cash' atau 'bank'

  
    -- JOB YANG BOLEH ISI / CEK DANA PEMERINTAH
    -- Selain job di bawah, admin server (ACE permission)
    -- selalu bisa isi dana lewat command.
  
    fundManagerJobs = {
        'disnaker',
    },

  
    -- DAFTAR ITEM YANG BISA DIJUAL
    -- Tinggal tambah baris baru di sini untuk nambah barang,
    -- gak perlu ubah script client/server sama sekali.
    -- item  = nama item di ox_inventory
    -- label = nama tampilan di UI
    -- price = harga per 1 item (diambil dari dana pemerintah)
    -- maxPerSell = batas maksimal jual sekali transaksi
  
    items = {
        { item = 'botol',          label = 'Botol Bekas',     price = 3000,   maxPerSell = 999 },
        { item = 'kaca',           label = 'Kaca',            price = 4000,   maxPerSell = 999 },
        { item = 'karung',         label = 'Karung',          price = 2000,   maxPerSell = 999 },
        { item = 'plastik',        label = 'Plastik',         price = 4000,   maxPerSell = 999 },
        { item = 'metalscrap',     label = 'Metal Scrap',     price = 5000,  maxPerSell = 999 },
        -- { item = 'kayu_batang',    label = 'Batang Kayu',     price = ,  maxPerSell = 999 },
        { item = 'kayu_potongan',  label = 'Potongan Kayu',   price = 6000,  maxPerSell = 999  },
    },
}



-- RETURN CONFIG


return Config