--[[

     Licensed under GNU General Public License v2
      * (c) 2013, Luca CPZ
      * (c) 2010, Adrian C. <anrxc@sysphere.org>

--]]

local helpers = require("lain.helpers")
local shell   = require("awful.util").shell
local wibox   = require("wibox")
local naughty  = require("naughty")
local string  = string

-- ALSA volume
-- lain.widget.alsa

local function factory(args)
    args           = args or {}
    local alsa     = { widget = args.widget or wibox.widget.textbox() }
    local timeout  = args.timeout or 5
    local settings = args.settings or function() end

    alsa.cmd           = args.cmd or "pactl"
    alsa.channel       = args.channel or "@DEFAULT_SINK@"
    alsa.togglechannel = args.togglechannel

    local format_cmd = string.format("%s get-sink-volume %s; pactl get-sink-mute %s", alsa.cmd, alsa.channel, alsa.channel)

    alsa.last = {}

    function alsa.update()
        helpers.async_with_shell(format_cmd, function(stdout)
            local l,s = string.match(stdout, "([%d]+)%%.*Mute: ([%l]+)")
            l = tonumber(l)
            if alsa.last.level ~= l or alsa.last.status ~= s then
                volume_now = { level = l, status = s }
                widget = alsa.widget
                settings()
                alsa.last = volume_now
            end
        end)
    end

    helpers.newtimer(string.format("alsa-%s-%s", alsa.cmd, alsa.channel), timeout, alsa.update)

    return alsa
end

return factory
