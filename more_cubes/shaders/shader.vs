#version 460 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aUV;

out vec3 vaPosition;
out vec2 vaUV;

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_Model;


void main()
{
    gl_Position = u_Projection * u_View * u_Model * vec4(aPos, 1.0);
    vaPosition = aPos;
    vaUV = aUV;
}