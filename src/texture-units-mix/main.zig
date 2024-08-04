// REF:
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-1/1.2.zig
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-2/main.zig
// https://learnopengl.com/code_viewer_gh.php?code=src/1.getting_started/2.1.hello_triangle/hello_triangle.cpp

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const zigimg = @import("zigimg");

const log = std.log.scoped(.@"texture-units-mix");

fn glGetProcAddress(_: glfw.GLProc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
    return glfw.getProcAddress(proc);
}

const window_width = 800;
const window_height = 600;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("Mem leak detected", .{});
        }
    }

    if (!glfw.init(.{})) {
        log.err("Failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // some how type inference for window won't work with zls
    const window: glfw.Window = glfw.Window.create(window_width, window_height, "Hello, OpenGL + GLFW!", null, null, .{
        .opengl_profile = .opengl_core_profile,
        .context_version_major = 3,
        .context_version_minor = 3,
    }) orelse {
        log.err("Failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined;
    try gl.loadExtensions(proc, glGetProcAddress);

    gl.viewport(0, 0, window_width, window_height);

    const vertex_shader = gl.Shader.create(gl.ShaderType.vertex);
    defer vertex_shader.delete();
    vertex_shader.source(1, &[_][]const u8{@embedFile("./vertex.glsl")});

    vertex_shader.compile();
    const vertex_shader_compile_log = try vertex_shader.getCompileLog(allocator);
    defer allocator.free(vertex_shader_compile_log);
    if (!std.mem.eql(u8, vertex_shader_compile_log, "")) {
        log.debug("{?s}", .{vertex_shader_compile_log});
    }

    const fragment_shader = gl.Shader.create(gl.ShaderType.fragment);
    defer fragment_shader.delete();
    fragment_shader.source(1, &[_][]const u8{@embedFile("./fragment.glsl")});

    fragment_shader.compile();
    const fragment_shader_compile_log = try fragment_shader.getCompileLog(allocator);
    defer allocator.free(fragment_shader_compile_log);
    if (!std.mem.eql(u8, fragment_shader_compile_log, "")) {
        log.debug("{?s}", .{fragment_shader_compile_log});
    }

    const shader_program = gl.Program.create();
    defer shader_program.delete();
    shader_program.attach(vertex_shader);
    shader_program.attach(fragment_shader);
    shader_program.link();

    const shader_program_compile_log = try shader_program.getCompileLog(allocator);
    defer allocator.free(shader_program_compile_log);
    if (!std.mem.eql(u8, shader_program_compile_log, "")) {
        log.debug("{?s}", .{shader_program_compile_log});
    }

    gl.texParameter(
        gl.TextureTarget.@"2d",
        gl.TextureParameter.wrap_s,
        gl.TextureParameterType(gl.TextureParameter.wrap_s).repeat,
    );
    gl.texParameter(
        gl.TextureTarget.@"2d",
        gl.TextureParameter.wrap_t,
        gl.TextureParameterType(gl.TextureParameter.wrap_t).repeat,
    );
    gl.texParameter(
        gl.TextureTarget.@"2d",
        gl.TextureParameter.mag_filter,
        gl.TextureParameterType(gl.TextureParameter.mag_filter).linear,
    );
    gl.texParameter(
        gl.TextureTarget.@"2d",
        gl.TextureParameter.min_filter,
        gl.TextureParameterType(gl.TextureParameter.min_filter).linear_mipmap_linear,
    );

    var t1_image = try zigimg.Image.fromMemory(allocator, @embedFile("./wood_texture.png")[0..]);
    defer t1_image.deinit();

    const t1 = gl.Texture.gen();
    defer t1.delete();

    t1.bind(gl.TextureTarget.@"2d");
    gl.textureImage2D(
        gl.TextureTarget.@"2d",
        0,
        gl.TextureInternalFormat.rgb,
        t1_image.width,
        t1_image.height,
        gl.PixelFormat.rgb,
        gl.PixelType.unsigned_byte,
        t1_image.pixels.asConstBytes().ptr,
    );
    t1.generateMipmap();
    t1.bindTo(1);

    var t2_image = try zigimg.Image.fromMemory(allocator, @embedFile("./awesomeface.png")[0..]);
    defer t2_image.deinit();

    const t2 = gl.Texture.gen();
    defer t2.delete();

    t2.bind(gl.TextureTarget.@"2d");
    gl.textureImage2D(
        gl.TextureTarget.@"2d",
        0,
        gl.TextureInternalFormat.rgba,
        t2_image.width,
        t2_image.height,
        gl.PixelFormat.rgba,
        gl.PixelType.unsigned_byte,
        t2_image.pixels.asConstBytes().ptr,
    );
    t2.generateMipmap();
    t2.bindTo(2);

    // zig fmt: off
    const vertices = [_]f32{
        // positions  texture coords
        0.5,  0.5,    0.0, 1.0, 0.0, // top right
        0.5,  -0.5,   0.0, 1.0, 1.0, // bottom right
        -0.5, -0.5,   0.0, 0.0, 1.0, // bottom left
        -0.5, 0.5,    0.0, 0.0, 0.0, // bottom right
        // NOTE: the coordinate system for an image is different to that of OpenGL
    };

    const indices = [_]u32{ // count from 0
        0, 1, 3, // first triangle
        1, 2, 3, // second triangle
    };
    // zig fmt: on

    const VAO = gl.VertexArray.create();
    defer VAO.delete();
    const VBO = gl.Buffer.create();
    defer VBO.delete();
    const EBO = gl.Buffer.create();
    defer EBO.delete();

    VAO.bind();
    VBO.bind(gl.BufferTarget.array_buffer);
    VBO.data(f32, &vertices, gl.BufferUsage.static_draw);
    EBO.bind(gl.BufferTarget.element_array_buffer);
    EBO.data(u32, &indices, gl.BufferUsage.static_draw);

    gl.vertexAttribPointer(0, 3, gl.Type.float, false, 5 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(1, 2, gl.Type.float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true });

        gl.useProgram(shader_program);
        gl.uniform1i(gl.getUniformLocation(shader_program, "t1"), 1);
        gl.uniform1i(gl.getUniformLocation(shader_program, "t2"), 2);

        gl.drawElements(gl.PrimitiveType.triangles, 6, gl.ElementType.unsigned_int, 0);

        window.swapBuffers();
        glfw.pollEvents();
    }
}
