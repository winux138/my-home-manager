local function watch_layout()
    -- Socket2 has no native event for position/scale-only layout changes.
    hl.on("monitor.layout_changed", function()
        if #hl.get_monitors() > 0 then
            hl.dispatch(hl.dsp.event("hypr-output-layout"))
        end
    end)
end

local function load_monitors()
    local monitors_config = os.getenv("MONIQUE_MONITORS_LUA")
    if not monitors_config or monitors_config == "" then
        local config_home = os.getenv("XDG_CONFIG_HOME")
        if not config_home or config_home == "" then
            local home = os.getenv("HOME")
            config_home = home and (home .. "/.config") or nil
        end
        monitors_config = config_home and (config_home .. "/monique/outputs/monitors.lua") or nil
    end
    if monitors_config then
        local file = io.open(monitors_config, "r")
        if file then
            file:close()
            local ok, err = pcall(dofile, monitors_config)
            if not ok then
                print("Monique monitor config failed: " .. tostring(err))
            end
        end
    end
end

local function toggle_debug_terminal()
    if #hl.get_windows({ class = "outer-debug" }) == 0 then
        hl.dispatch(hl.dsp.exec_cmd("foot --app-id=outer-debug", {
            float = true,
            workspace = "special:outer-debug",
        }))
        return
    end

    hl.dispatch(hl.dsp.workspace.toggle_special("outer-debug"))
end

local function place_host(output, pid, workspace, geometry)
    for _, window in ipairs(hl.get_windows({ mapped = true, title = "aquamarine - " .. output })) do
        if window.pid == pid then
            local function apply(action)
                local result = hl.dispatch(action)
                assert(result.ok, result.error)
            end

            if geometry then
                apply(hl.dsp.window.float({ action = "enable", window = window }))
            end
            apply(hl.dsp.window.move({ workspace = workspace, follow = false, window = window }))
            if geometry then
                apply(hl.dsp.window.resize({ x = geometry.width, y = geometry.height, relative = false, window = window }))
                apply(hl.dsp.window.move({ x = geometry.x, y = geometry.y, relative = false, window = window }))
            end
            return true
        end
    end
    return false
end

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function workspace_swipe(inner_runtime, minimum_distance)
    local delta = 0
    return {
        start = function()
            delta = 0
        end,
        update = function(event)
            delta = delta + event.delta.x
        end,
        finish = function(event)
            local distance = delta
            delta = 0
            if event.cancelled or math.abs(distance) < minimum_distance then
                return
            end

            local root = os.getenv("XDG_RUNTIME_DIR")
            local file = root and io.open(root .. "/hypr-session/inner.instance", "r")
            if not file then
                return
            end
            local inner = file:read("*l")
            file:close()
            if not inner or inner == "" then
                return
            end

            local workspace = distance < 0 and "m+1" or "m-1"
            local action = string.format(
                "dofile(%q).sync_after(hl.dsp.focus({ workspace = %q }))()",
                inner_runtime,
                workspace
            )
            hl.exec_cmd("hyprctl -q -i " .. shell_quote(inner) .. " eval " .. shell_quote(action))
        end,
    }
end

return {
    watch_layout = watch_layout,
    load_monitors = load_monitors,
    toggle_debug_terminal = toggle_debug_terminal,
    place_host = place_host,
    workspace_swipe = workspace_swipe,
}
