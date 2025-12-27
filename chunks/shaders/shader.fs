#version 460 core

in vec3 vaNormal;
in vec2 vaUV;

out vec4 FragColor;

uniform sampler2D u_texture;

void main()
{
    vec3 lightDir = normalize(vec3(0.4, 1.0, 0.6)); // random sun direction
    float light = max(dot(normalize(vaNormal), lightDir), 0.15);

    vec4 color = texture(u_texture, vaUV);
    FragColor = vec4(color.rgb * light, color.a);
}