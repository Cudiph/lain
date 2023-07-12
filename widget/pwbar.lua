--[[

     Licensed under GNU General Public License v2
      * (c) 2013, Luca CPZ
      * (c) 2013, Rman

--]]

local helpers  = require("lain.helpers")
local awful    = require("awful")
local naughty  = require("naughty")
local wibox    = require("wibox")
local math     = math
local string   = string
local type     = type
local tonumber = tonumber

-- ALSA volume bar
-- lain.widget.pwbar

local function factory(args)
    local pwbar = {
        colors = {
            background = "#000000",
            mute       = "#EB8F8F",
            unmute     = "#A4CE8A"
        },

        _current_level = 0,
        _playback      = "off"
    }

    args             = args or {}

    local timeout    = args.timeout or 5
    local settings   = args.settings or function() end
    local width      = args.width or 63
    local height     = args.height or 1
    local margins    = args.margins or 1
    local ticks      = args.ticks or false
    local ticks_size = args.ticks_size or 7
    local tick       = args.tick or "|"
    local tick_pre   = args.tick_pre or "["
    local tick_post  = args.tick_post or "]"
    local tick_none  = args.tick_none or " "

    pwbar.cmd                 = args.cmd or "pactl"
    pwbar.channel             = args.channel or "@DEFAULT_SINK@"
    pwbar.colors              = args.colors or pwbar.colors
    pwbar.followtag           = args.followtag or false
    pwbar.notification_preset = args.notification_preset

    if not pwbar.notification_preset then
        pwbar.notification_preset = { font = "Monospace 10" }
    end

    local format_cmd = string.format("%s get-sink-volume %s; pactl get-sink-mute %s", pwbar.cmd, pwbar.channel, pwbar.channel)

    pwbar.bar = wibox.widget {
        color            = pwbar.colors.unmute,
        background_color = pwbar.colors.background,
        forced_height    = height,
        forced_width     = width,
        margins          = margins,
        paddings         = margins,
        ticks            = ticks,
        ticks_size       = ticks_size,
        widget           = wibox.widget.progressbar
    }

    pwbar.tooltip = awful.tooltip({ objects = { pwbar.bar } })

    function pwbar.update(callback)
        helpers.async_with_shell(format_cmd, function(mixer)
            local vol, muted = string.match(mixer, "([%d]+)%%.*Mute: ([%l]+)")

            if not vol or not muted then return end

            if vol ~= pwbar._current_level or muted ~= pwbar._playback then
                pwbar._current_level = tonumber(vol)
                pwbar.bar:set_value(pwbar._current_level / 100)
                if muted == "yes" then
                    pwbar._playback = "off"
                    pwbar.tooltip:set_text("[Muted]")
                    pwbar.bar.color = pwbar.colors.mute
                else
                    pwbar._playback = "on"
                    pwbar.tooltip:set_text(string.format("%s: %s", pwbar.channel, vol))
                    pwbar.bar.color = pwbar.colors.unmute
                end

                volume_now = {
                    level  = pwbar._current_level,
                    status = pwbar._playback
                }

                settings()

                if type(callback) == "function" then callback() end
            end
        end)
    end

    function pwbar.notify()
        pwbar.update(function()
            local preset = pwbar.notification_preset

            preset.title = string.format("%s - %s%%", "Default", pwbar._current_level)

            if pwbar._playback == "off" then
                preset.title = preset.title .. " Muted"
            end

            -- tot is the maximum number of ticks to display in the notification
            local tot = pwbar.notification_preset.max_ticks

            if not tot then
                local wib = awful.screen.focused().mywibox
                -- if we can grab mywibox, tot is defined as its height if
                -- horizontal, or width otherwise
                if wib then
                    if wib.position == "left" or wib.position == "right" then
                        tot = wib.width
                    else
                        tot = wib.height
                    end
                -- fallback: default horizontal wibox height
                else
                    tot = 20
                end
            end

            local int = math.modf((pwbar._current_level / 100) * tot)
            preset.text = string.format(
                "%s%s%s%s",
                tick_pre,
                string.rep(tick, int),
                string.rep(tick_none, tot - int),
                tick_post
            )

            if pwbar.followtag then preset.screen = awful.screen.focused() end

            if not pwbar.notification then
                pwbar.notification = naughty.notify {
                    preset  = preset,
                    destroy = function() pwbar.notification = nil end
                }
            else
                naughty.replace_text(pwbar.notification, preset.title, preset.text)
            end
        end)
    end

    helpers.newtimer(string.format("pwbar-%s-%s", pwbar.cmd, pwbar.channel), timeout, pwbar.update)

    return pwbar
end

return factory
