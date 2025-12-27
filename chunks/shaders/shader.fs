#version 460 core
out vec4 FragColor;

in vec3 vaPosition;
in vec2 vaUV;

uniform sampler2D u_texture;

void main()
{
    FragColor = texture(u_texture, vaUV);
}