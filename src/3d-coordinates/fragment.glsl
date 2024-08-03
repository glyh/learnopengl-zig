#version 330 core
out vec4 FragColor;

in vec2 texCoord;

uniform sampler2D t1;
uniform sampler2D t2;

void main()
{
    FragColor = mix(texture(t1, texCoord), texture(t2, texCoord), 0.2);
}
