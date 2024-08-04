// REF:
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-1/1.2.zig
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-2/main.zig
// https://learnopengl.com/code_viewer_gh.php?code=src/1.getting_started/2.1.hello_triangle/hello_triangle.cpp

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const zigimg = @import("zigimg");
const za = @import("zalgebra");

const log = std.log.scoped(.@"3d-coordinates");

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
        // positions       texture coords
        -0.5, -0.5, -0.5,  0.0, 0.0,
         0.5, -0.5, -0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5,  0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 0.0,

        -0.5, -0.5,  0.5,  0.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 1.0,
        -0.5,  0.5,  0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,

        -0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5, -0.5,  1.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5,  0.5,  1.0, 0.0,

         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5,  0.5,  0.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,

        -0.5, -0.5, -0.5,  0.0, 1.0,
         0.5, -0.5, -0.5,  1.0, 1.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
         0.5, -0.5,  0.5,  1.0, 0.0,
        -0.5, -0.5,  0.5,  0.0, 0.0,
        -0.5, -0.5, -0.5,  0.0, 1.0,

        -0.5,  0.5, -0.5,  0.0, 1.0,
         0.5,  0.5, -0.5,  1.0, 1.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
         0.5,  0.5,  0.5,  1.0, 0.0,
        -0.5,  0.5,  0.5,  0.0, 0.0,
        -0.5,  0.5, -0.5,  0.0, 1.0,
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

    gl.vertexAttribPointer(0, 3, gl.Type.float, false, 5 * @sizeOf(f32), 0);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(1, 2, gl.Type.float, false, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.enableVertexAttribArray(1);

    gl.useProgram(shader_program);

    gl.uniform1i(gl.getUniformLocation(shader_program, "t1"), 1);
    gl.uniform1i(gl.getUniformLocation(shader_program, "t2"), 2);

    const view = za.Mat4.fromTranslate(za.Vec3.new(0.0, 0.0, -3.0));
    gl.uniformMatrix4fv(
        gl.getUniformLocation(shader_program, "view"),
        false,
        &[_][4][4]f32{view.data},
    );

    const projection = za.Mat4.perspective(
        45.0,
        @as(f32, @floatFromInt(window_width)) / @as(f32, @floatFromInt(window_height)),
        0.1,
        100.0,
    );
    gl.uniformMatrix4fv(
        gl.getUniformLocation(shader_program, "projection"),
        false,
        &[_][4][4]f32{projection.data},
    );

    gl.enable(gl.Capabilities.depth_test);

    const cube_positions = [_]za.Vec3{
        za.Vec3.new(0.0, 0.0, 0.0),
        za.Vec3.new(2.0, 5.0, -15.0),
        za.Vec3.new(-1.5, -2.2, -2.5),
        za.Vec3.new(-3.8, -2.0, -12.3),
        za.Vec3.new(2.4, -0.4, -3.5),
        za.Vec3.new(-1.7, 3.0, -7.5),
        za.Vec3.new(1.3, -2.0, -2.5),
        za.Vec3.new(1.5, 2.0, -2.5),
        za.Vec3.new(1.5, 0.2, -1.5),
        za.Vec3.new(-1.3, 1.0, -1.5),
    };

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true, .depth = true });

        for (cube_positions) |pos| {
            const model = za.Mat4
                .fromTranslate(pos)
                .rotate(@as(f32, @floatCast(glfw.getTime())) * 50.0, za.Vec3.new(0.5, 1.0, 0.0));
            gl.uniformMatrix4fv(
                gl.getUniformLocation(shader_program, "model"),
                false,
                &[_][4][4]f32{model.data},
            );
            gl.drawArrays(gl.PrimitiveType.triangles, 0, 36);
        }

        window.swapBuffers();
        glfw.pollEvents();
    }
}
