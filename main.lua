local inspect           = require "inspect"
local SocialNetwork     = require "social_network"

do
    if #arg ~= 2 then
        print("USAGE:", "lua", arg[0], "(username1)", "(username2)")
        return
    end
    local network = SocialNetwork.new()
    local path = network:getSeparation(arg[1], arg[2])
    print()

    if not path then
        print "NO PATH FOUND :("
        return
    end

    print("Degrees of separation:", #path - 1)
    for i = 1, #path do
        local username = path[i]
        print(username)
        if i ~= #path then print("|") end
    end
end
