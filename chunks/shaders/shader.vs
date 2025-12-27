#version 460 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec2 aUV;

out vec3 vaNormal;
out vec2 vaUV;

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_Model;


void main()
{
    vaNormal = mat3(u_Model) * aNormal;
    vaUV = aUV;
    gl_Position = u_Projection * u_View * u_Model * vec4(aPos, 1.0);
}   