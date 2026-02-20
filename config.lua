Config = {}

-- Still Settings
Config.Prop = 'p_still03x'
Config.BrewTime = 300000 -- 5 minutes in milliseconds

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

-- Recipe
Config.Recipe = {
    { item = 'sugar', amount = 1, label = 'Sugar' },
    { item = 'malt', amount = 1, label = 'Malt' },
    { item = 'water', amount = 1, label = 'Water' }
}

-- Output
Config.Output = {
    item = 'moonshine',
    amount = 1
}