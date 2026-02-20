Config = {}

-- Still Settings
Config.Prop = 'p_still03x'
Config.BrewTime = 600000 -- 10 minutes in milliseconds

-- Admin Settings
Config.AdminGroups = {
    'admin',
    'god',
    'superadmin',
    'mod'
}

-- Command
Config.AdminCommand = 'stills'

-- Blip Settings
Config.Blip = {
    Enabled = true,
    Sprite = -392465725,
    Scale = 0.2,
    Name = 'Moonshine Still'
}

-- Smoke Effect Settings
Config.Smoke = {
    Enabled = true,
    Group = 'scr_adv_sok',
    Name = 'scr_adv_sok_torchsmoke',
    Scale = 1.0,
    OffsetZ = -1.6
}



-- Output
Config.Output = {
    item = 'moonshine',
    amount = 1
}

Config.Recipe = {
    {
        item = 'sugar',
        label = 'Sugar',
        amount = 1,
        source = 'General Store',
        sourceDetails = 'Available at Stores or farming '
    },
    {
        item = 'malt',
        label = 'Malt',
        amount = 1,
        source = 'Farming or Market',
        sourceDetails = 'Can be harvested from farms or bought at market stalls'
    },
    {
        item = 'water',
        label = 'Water',
        amount = 1,
        source = 'shops',
        sourceDetails = 'Collect from any shops'
    }
    
}
