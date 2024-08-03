// REF:
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-1/1.2.zig
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-2/main.zig
// https://learnopengl.com/code_viewer_gh.php?code=src/1.getting_started/2.1.hello_triangle/hello_triangle.cpp

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const zigimg = @import("zigimg");

const log = std.log.scoped(.triangle);

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

    var texture_image = try zigimg.Image.fromMemory(allocator, @embedFile("./wood_texture.png")[0..]);
    defer texture_image.deinit();

    // var texture_rgba = try zigimg.PixelFormatConverter.convert(allocator, &texture_image.pixels, zigimg.PixelFormat.rgb24);
    // defer texture_rgba.deinit(allocator);

    const texture = gl.Texture.gen();
    defer texture.delete();

    texture.bind(gl.TextureTarget.@"2d");
    gl.textureImage2D(
        gl.TextureTarget.@"2d",
        0,
        gl.TextureInternalFormat.rgb,
        texture_image.width,
        texture_image.height,
        gl.PixelFormat.rgb,
        gl.PixelType.unsigned_byte,
        texture_image.pixels.asConstBytes().ptr,
    );
    texture.generateMipmap();

    // zig fmt: off
    const vertices = [_]f32{
        // positions      //colors        // textures
        0.5,  -0.5, 0.0,  1.0, 0.0, 0.0,  1.0, 0.0, // bottom right
        -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  0.0, 0.0, // bottom left
        0.0,  0.5,  0.0,  0.0, 0.0, 1.0,  0.5, 1.0, // top
    };
    // zig fmt: on

    const VAO = gl.VertexArray.create();
    defer VAO.delete();
    const VBO = gl.Buffer.create();
    defer VBO.delete();

    VAO.bind();

    VBO.bind(gl.BufferTarget.array_buffer);

    VBO.data(f32, &vertices, gl.BufferUsage.static_draw);
    gl.vertexAttribPointer(0, 3, gl.Type.float, false, 8 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(1, 3, gl.Type.float, false, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(2, 2, gl.Type.float, false, 8 * @sizeOf(f32), 6 * @sizeOf(f32));
    gl.enableVertexAttribArray(2);

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true });

        gl.useProgram(shader_program);

        const now: f32 = @floatCast(glfw.getTime());
        const green_value = std.math.sin(now) / 2.0 + 0.5;
        const our_color = gl.getUniformLocation(shader_program, "ourColor");
        gl.uniform4f(our_color, 0.0, green_value, 0.0, 0.0);

        gl.drawArrays(gl.PrimitiveType.triangles, 0, 3);

        window.swapBuffers();
        glfw.pollEvents();
    }
}