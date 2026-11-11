local function clamp(value)
    return math.max(0, math.min(255, value))
end

local function channel(value)
    -- GLSL always uses a decimal point, regardless of the compositor's locale.
    return (string.format("%.7f", value / 255):gsub("%D+", "."))
end

local function write(kelvin, path)
    local temperature = math.floor(kelvin / 100)
    local red, green, blue
    if temperature <= 66 then
        red = 255
        green = clamp(99.4708025861 * math.log(temperature) - 161.1195681661)
        blue = temperature <= 19 and 0 or clamp(math.log(temperature - 10) * 138.5177312231 - 305.0447927307)
    else
        local logarithm = math.log(temperature - 60)
        red = clamp(329.698727446 * math.exp(-0.1332047592 * logarithm))
        green = clamp(288.1221695283 * math.exp(-0.0755148492 * logarithm))
        blue = 255
    end

    local shader = string.format([[#version 300 es

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    fragColor = vec4(color.rgb * vec3(%s, %s, %s), color.a);
}
]], channel(red), channel(green), channel(blue))
    local file = assert(io.open(path, "w"))
    local written, write_error = file:write(shader)
    local closed, close_error = file:close()
    assert(written, write_error)
    assert(closed, close_error)
end

local function apply(kelvin, shader_path)
    if not kelvin then
        hl.config({ decoration = { screen_shader = "" } })
        return
    end
    local tmp = shader_path .. ".tmp"
    local ok, err = pcall(write, kelvin, tmp)
    if not ok then
        os.remove(tmp)
        error(err)
    end
    assert(os.rename(tmp, shader_path))
    hl.config({ decoration = { screen_shader = shader_path } })
end

return {
    apply = apply,
    write = write,
}
