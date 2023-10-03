Config.toggle_helicam = 51 -- control id of the button by which to toggle the helicam mode. Default: INPUT_CONTEXT (E)
Config.toggle_vision = 25 -- control id to toggle vision mode. Default: INPUT_AIM (Right mouse btn)
Config.toggle_rappel = 154 -- control id to rappel out of the heli. Default: INPUT_DUCK (X)
Config.toggle_spotlight = 74 -- control id to toggle the front spotlight Default: INPUT_VEH_HEADLIGHT (H)
Config.toggle_lock_on = 22 -- control id to lock onto a vehicle with the camera. Default is INPUT_SPRINT (spacebar)

Config.PoliceHelicopter = "MAVERICK"

Config.HeliSettings = {
    ["MAVERICK"] = { --- Model name
        ["extras"] = {
            ["1"] = true, -- on/off
            ["2"] = true,
            ["3"] = true,
            ["4"] = true,
            ["5"] = true,
            ["6"] = true,
            ["7"] = true,
            ["8"] = true,
            ["9"] = true,
            ["10"] = true,
            ["11"] = true,
            ["12"] = true,
            ["13"] = true,
        },
		["livery"] = 1,
    },
}