local outer_instance = os.getenv("OUTER_HYPRLAND_INSTANCE")
local function sync_outer_cursor()
    if not outer_instance then
        return
    end

    local pos = hl.get_cursor_pos()
    hl.exec_cmd(string.format(
        "hyprctl -q -i \"$OUTER_HYPRLAND_INSTANCE\" dispatch 'hl.dsp.cursor.move({ x = %.3f, y = %.3f })'",
        pos.x,
        pos.y
    ))
end

local function sync_after(action)
    return function()
        if type(action) == "function" then
            action()
        else
            hl.dispatch(action)
        end
        sync_outer_cursor()
    end
end

local function monitor_action(offset, move_window)
    return function()
        local monitors = hl.get_monitors()
        local active = hl.get_active_monitor()
        if #monitors < 2 or not active then
            return
        end

        table.sort(monitors, function(a, b)
            if a.x ~= b.x then
                return a.x < b.x
            end
            if a.y ~= b.y then
                return a.y < b.y
            end
            return a.id < b.id
        end)

        for index, monitor in ipairs(monitors) do
            if monitor.id == active.id then
                local target = monitors[((index - 1 + offset) % #monitors) + 1]
                if move_window then
                    hl.dispatch(hl.dsp.window.move({ monitor = target }))
                else
                    hl.dispatch(hl.dsp.focus({ monitor = target }))
                end
                return
            end
        end
    end
end

local function gather_windows(shown, disconnected)
    local monitor = hl.get_active_monitor()
    assert(monitor and shown[monitor.name] and not disconnected[monitor.name], "Focus a connected visible monitor first")
    local focused = hl.get_active_window()
    local special = monitor.active_special_workspace
    local target = focused and focused.workspace or special or monitor.active_workspace
    assert(target, "No focused workspace")
    local windows = {}
    for _, window in ipairs(hl.get_windows({ mapped = true })) do
        if window.monitor and disconnected[window.monitor.name] then
            windows[#windows + 1] = window
        end
    end
    for _, window in ipairs(windows) do
        local result = hl.dispatch(hl.dsp.window.move({ window = window, workspace = target, follow = false }))
        assert(result.ok, result.error)
        assert(window.workspace == target and window.monitor == monitor, "Window did not reach the focused workspace")
    end
    monitor:set_special_workspace(special)
    return string.format("%d %s %d", monitor.id, focused and focused.address or "none", #windows)
end

local function restore_focus(target_monitor_id, focused_address, cursor)
    local result = hl.dispatch(hl.dsp.focus({ monitor = target_monitor_id }))
    assert(result.ok, result.error)
    for _, window in ipairs(hl.get_windows({ mapped = true })) do
        if window.address == focused_address then
            result = hl.dispatch(hl.dsp.focus({ window = window }))
            assert(result.ok, result.error)
        end
    end
    result = hl.dispatch(hl.dsp.cursor.move(cursor))
    assert(result.ok, result.error)
    return true
end

local function autostart(commands)
    if os.getenv("HYPR_AUTOSTART") ~= "1" then
        return
    end
    hl.on("hyprland.start", function()
        for _, command in ipairs(commands) do
            hl.exec_cmd(command)
        end
    end)
end

return {
    autostart = autostart,
    gather_windows = gather_windows,
    monitor_action = monitor_action,
    restore_focus = restore_focus,
    sync_after = sync_after,
}
