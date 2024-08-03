## Learn OpenGL with Zig! 

A series of demos from [Learn OpenGL](https://learnopengl.com/) implemented in [Zig](https://github.com/ziglang/zig).

Here are some libraries used compared to the tutorial:

| C Library | Corresponding Zig Library |
| - | - | 
| OpenGL | [zgl](https://github.com/ziglibs/zgl) |
| GLFW | [mach-glfw](https://github.com/slimsag/mach-glfw) |
| GLAD | builtin to zgl |
| stb_image.h | [zigimg](https://github.com/zigimg/zigimg) |
| GLM | [zalgebra](https://github.com/glyh/zalgebra/tree/main) |

### Requirement

- Zig 0.13.0
- GLFW
- OpenGL 3.3 Core

### Usage

Run `zig build -h` to see a list of demos. For example, run `zig build run-hello-triangle` to see a triangle.

### Reference 
- [Flecart/zig-learnopengl: Pure Zig implementation of the popular LearnOpenGL tutorial](https://github.com/Flecart/zig-learnopengl)

