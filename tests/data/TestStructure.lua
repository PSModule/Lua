{
    name = "ElvUI",
    version = "13.74",
    enabled = true,
    debug = false,
    maxRetries = 3,
    scaling = 0.85,
    description = "A user interface replacement for World of Warcraft",
    authors = {
        "Elv",
        "Simpy",
        "Blazeflack"
    },
    emptyList = {},
    unitframes = {
        enabled = true,
        playerWidth = 270,
        playerHeight = 54,
        targetWidth = 270,
        targetHeight = 54,
        colors = {
            health = {0.31, 0.45, 0.63},
            power = {0.0, 0.44, 0.87},
            castbar = {0.86, 0.86, 0.0}
        }
    },
    chat = {
        fontSize = 12,
        tabFontSize = 12,
        panelWidth = 412,
        panelHeight = 180,
        fadeChat = true,
        keywords = "ElvUI,Raid,Guild"
    },
    actionbars = {
        bar1 = {
            enabled = true,
            buttons = 12,
            buttonsPerRow = 12,
            buttonSize = 30,
            buttonSpacing = 4,
            backdrop = false
        },
        bar2 = {
            enabled = true,
            buttons = 12,
            buttonsPerRow = 12,
            buttonSize = 30,
            buttonSpacing = 4,
            backdrop = false
        }
    },
    minimap = {
        size = 175,
        locationText = "SHOW"
    },
    tooltip = {
        cursorAnchor = false,
        healthBar = true,
        playerTitles = true,
        guildRanks = true
    },
    ["specialKey"] = "key with spaces",
    unicodeNote = "Héllo Wörld"
}
