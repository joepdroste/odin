#version 460 core
layout (location = 0) in vec3 aPos;

out vec3 vaPosition;

uniform mat4 u_MVP;

void main()
{
    gl_Position = u_MVP * vec4(aPos, 1.0);
    vaPosition = aPos;
}