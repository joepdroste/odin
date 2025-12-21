#version 460 core
out vec4 FragColor;

in vec3 vaPosition;

void main()
{
    FragColor = vec4(vaPosition.x, vaPosition.y, vaPosition.z, 1.0);
}