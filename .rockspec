package = "social_network"
version = "1.0-1"

source = {
    url = "."
}

dependencies = {
    "lua >= 5.4",
    "lsqlite3",
    "luasocket",
    "dkjson"
}

build = {
    type = "builtin",
    modules = {
        ["social_network"] = "social_network.lua",
        ["utils"] = "utils.lua",
    }
}
