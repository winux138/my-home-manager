#version 300 es

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    fragColor = vec4(color.rgb * vec3(1.0, 0.8530675, 0.7350351), color.a);
}
