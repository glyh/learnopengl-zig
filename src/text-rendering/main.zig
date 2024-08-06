// REF:
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-1/1.2.zig
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-2/main.zig
// https://learnopengl.com/code_viewer_gh.php?code=src/1.getting_started/2.1.hello_triangle/hello_triangle.cpp

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const freetype = @import("freetype");
const za = @import("zalgebra");

const log = std.log.scoped(.@"text-rendering");

fn glGetProcAddress(_: glfw.GLProc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
    return glfw.getProcAddress(proc);
}

const window_width = 800;
const window_height = 600;

var char_map: std.AutoHashMap(u32, Character) = undefined;

const Character = struct {
    texture: gl.Texture,
    size: za.Vec2,
    bearing: za.Vec2,
    advance: c_long,

    fn init(tex: gl.Texture, glyph: freetype.GlyphSlot) Character {
        return .{
            .texture = tex,
            .bearing = za.Vec2.new(
                @as(gl.Float, @floatFromInt(glyph.bitmapLeft())),
                @as(gl.Float, @floatFromInt(glyph.bitmapTop())),
            ),
            .size = za.Vec2.new(
                @as(gl.Float, @floatFromInt(glyph.bitmap().width())),
                @as(gl.Float, @floatFromInt(glyph.bitmap().rows())),
            ),
            .advance = glyph.advance().x,
        };
    }
};

fn renderText(
    s: gl.Program,
    vbo: gl.Buffer,
    text: []const u8,
    x_: gl.Float,
    y: gl.Float,
    scale: gl.Float,
    color: za.Vec3,
    showBoundingBox: bool,
) void {
    var x = x_;
    s.use();
    gl.uniform3f(gl.getUniformLocation(s, "textColor"), color.x(), color.y(), color.z());
    gl.uniform1i(gl.getUniformLocation(s, "showBoundingBox"), if (showBoundingBox) 1 else 0);
    for (text) |char| {
        const char_u32 = @as(u32, @intCast(char));
        const ch = char_map.get(char_u32).?;

        const xpos = x + ch.bearing.x() * scale;
        const ypos = y - (ch.size.y() - ch.bearing.y()) * scale;
        const w = ch.size.x() * scale;
        const h = ch.size.y() * scale;

        // zig fmt: off
        const vertices = [_]gl.Float{
            xpos,     ypos + h, 0.0, 0.0,
            xpos,     ypos,     0.0, 1.0 ,
            xpos + w, ypos,     1.0, 1.0,

            xpos,     ypos + h, 0.0, 0.0,
            xpos + w, ypos,     1.0, 1.0,
            xpos + w, ypos + h, 1.0, 0.0,
        };
        // zig fmt: on

        ch.texture.bind(.@"2d");
        vbo.subData(0, gl.Float, &vertices);
        gl.drawArrays(.triangles, 0, 6);
        x += @as(gl.Float, @floatFromInt(ch.advance >> 6)) * scale;
    }
}

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

    const vertex_shader = gl.Shader.create(.vertex);
    defer vertex_shader.delete();
    vertex_shader.source(1, &[_][]const u8{@embedFile("./vertex.glsl")});

    vertex_shader.compile();
    const vertex_shader_compile_log = try vertex_shader.getCompileLog(allocator);
    defer allocator.free(vertex_shader_compile_log);
    if (!std.mem.eql(u8, vertex_shader_compile_log, "")) {
        log.debug("{?s}", .{vertex_shader_compile_log});
    }

    const fragment_shader = gl.Shader.create(.fragment);
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

    gl.useProgram(shader_program);

    const lib = try freetype.Library.init();
    defer lib.deinit();

    const font_file = @embedFile("./Ubuntu-R.ttf");
    const face = try lib.createFaceMemory(font_file, 0);
    try face.setPixelSizes(0, 48);

    gl.pixelStore(.unpack_alignment, 1);

    char_map = std.AutoHashMap(u32, Character).init(allocator);
    defer char_map.deinit();
    defer {
        var texture_it = char_map.valueIterator();
        while (texture_it.next()) |pt| {
            pt.texture.delete();
        }
    }

    for (0..128) |ascii_u| {
        const ascii_u32 = @as(u32, @intCast(ascii_u));
        try face.loadChar(ascii_u32, .{ .render = true });
        const char_texture = gl.Texture.gen();
        try char_map.put(ascii_u32, Character.init(char_texture, face.glyph()));
        char_texture.bind(.@"2d");
        gl.textureImage2D(
            .@"2d",
            0,
            .red,
            face.glyph().bitmap().width(),
            face.glyph().bitmap().rows(),
            .red,
            .unsigned_byte,
            @ptrCast(face.glyph().bitmap().buffer()),
        );
        gl.texParameter(.@"2d", .wrap_s, .clamp_to_edge);
        gl.texParameter(.@"2d", .wrap_t, .clamp_to_edge);
        gl.texParameter(.@"2d", .mag_filter, .linear);
        gl.texParameter(.@"2d", .min_filter, .linear);
    }

    gl.enable(.blend);
    gl.blendFunc(.src_alpha, .one_minus_src_alpha);

    gl.activeTexture(.texture_0);

    // NOTE:
    // zalegebra doesn't have a 4-param overload, this is taken from:
    // https://github.com/g-truc/glm/blob/33b4a621a697a305bc3a7610d290677b96beb181/glm/ext/matrix_clip_space.inl#L4
    const projection = za.Mat4.orthographic(0.0, 800.0, 0.0, 600.0, -1.0, 1.0);
    gl.uniformMatrix4fv(
        gl.getUniformLocation(shader_program, "projection"),
        false,
        &[_][4][4]gl.Float{projection.data},
    );

    const VAO = gl.VertexArray.create();
    defer VAO.delete();
    const VBO = gl.Buffer.create();
    defer VBO.delete();

    VAO.bind();
    VBO.bind(.array_buffer);
    gl.bufferUninitialized(.array_buffer, gl.Float, 6 * 4, .dynamic_draw);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 4, gl.Type.float, false, 4 * @sizeOf(gl.Float), 0);

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true });

        renderText(shader_program, VBO, "This is sample text", 25.0, 100.0, 1.0, za.Vec3.new(0.5, 0.8, 0.2), false);
        renderText(shader_program, VBO, "This is sample text", 25.0, 30.0, 1.0, za.Vec3.new(0.5, 0.8, 0.2), true);

        renderText(shader_program, VBO, "(C) LearnOpenGL.com", 500.0, 570.0, 0.5, za.Vec3.new(0.3, 0.7, 0.9), false);
        renderText(shader_program, VBO, "(C) LearnOpenGL.com", 500.0, 540.0, 0.5, za.Vec3.new(0.3, 0.7, 0.9), true);

        window.swapBuffers();
        glfw.pollEvents();
    }
}
