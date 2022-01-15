ox = {
    -- Enable support for ox_inventory
	inventory = false,

    /*
    * Show or hide gas stations blips
    * 0 - Hide all
    * 1 - Show nearest
    * 2 - Show all
    */
    showBlips = 0,

    -- What keys to disable while fueling
    disabledKeys = { 0, 22, 23, 24, 29, 30, 31, 37, 44, 56, 82, 140, 166, 167, 168, 170, 288, 289, 311, 323 },

    -- Fuel cost
    refillCost = 100,

    -- Fuel usage multiplier based on class (default 1.0)
    classUsage = {
        [13] = 0.0, -- Cycles
    },

    -- Fuel usage per second based on vehicle RPM
    rpmUsage = {
        [1.0] = 0.14,
        [0.9] = 0.12,
        [0.8] = 0.10,
        [0.7] = 0.09,
        [0.6] = 0.08,
        [0.5] = 0.07,
        [0.4] = 0.05,
        [0.3] = 0.04,
        [0.2] = 0.02,
        [0.1] = 0.01,
        [0.0] = 0.00,
    }
}