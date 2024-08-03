#version 330 core

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec2 aTexCoord;

out vec2 texCoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 1.0);
    texCoord.x = aTexCoord.x;
    texCoord.y = 1.0 - aTexCoord.y; // image coordinates is different from texture coordinates
}
