// https://github.com/harfbuzz/harfbuzz/issues/2714
const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const freetype = @import("freetype");
const za = @import("zalgebra");
const harfbuzz = @import("harfbuzz");

const log = std.log.scoped(.@"text-rendering-modern");

fn glGetProcAddress(_: glfw.GLProc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
    return glfw.getProcAddress(proc);
}

const window_width = 800;
const window_height = 600;

const font_pt = 20.0;
const frac_pt = 64.0;
const pt_per_inch = 72.0;

fn intToGLFloat(in: anytype) gl.Float {
    return @as(gl.Float, @floatFromInt(in));
}

fn renderText(
    ft_face: freetype.Face,
    hb_font: harfbuzz.Font,
    s: gl.Program,
    vbo: gl.Buffer,
    text: []const u8,
    x: gl.Float,
    y: gl.Float,
    color: za.Vec3,
    showBoundingBox: bool,
    dpi_x: gl.Float,
    dpi_y: gl.Float,
) !void {
    s.use();
    gl.uniform3f(gl.getUniformLocation(s, "textColor"), color.x(), color.y(), color.z());
    gl.uniform1i(gl.getUniformLocation(s, "showBoundingBox"), if (showBoundingBox) 1 else 0);

    const text_buffer = harfbuzz.Buffer.init().?;
    defer text_buffer.deinit();

    text_buffer.addUTF8(text, 0, null);
    text_buffer.guessSegmentProps();
    // text_buffer.setDirection(.ltr);
    // text_buffer.setScript(.han);
    // text_buffer.setLanguage(harfbuzz.Language.fromString("zh-Hans"));
    hb_font.shape(text_buffer, null);

    const glyph_infos = text_buffer.getGlyphInfos();
    const glyph_positions = text_buffer.getGlyphPositions().?;

    var cursor_x: gl.Float = 0.0;
    var cursor_y: gl.Float = 0.0;

    for (glyph_infos, glyph_positions) |*info, *pos| {
        // Units for harfbuzz font: 1/64 pt
        const glyph_index = info.codepoint;
        try ft_face.loadGlyph(glyph_index, .{ .render = true });

        const char_texture = gl.Texture.gen();
        defer char_texture.delete();

        char_texture.bind(.@"2d");
        gl.textureImage2D(
            .@"2d",
            0,
            .red,
            ft_face.glyph().bitmap().width(),
            ft_face.glyph().bitmap().rows(),
            .red,
            .unsigned_byte,
            @ptrCast(ft_face.glyph().bitmap().buffer()),
        );
        gl.texParameter(.@"2d", .wrap_s, .clamp_to_edge);
        gl.texParameter(.@"2d", .wrap_t, .clamp_to_edge);
        gl.texParameter(.@"2d", .mag_filter, .linear);
        gl.texParameter(.@"2d", .min_filter, .linear);

        const w = intToGLFloat(ft_face.glyph().bitmap().width());
        const h = intToGLFloat(ft_face.glyph().bitmap().rows());

        // 1/64 pt => px
        const final_frac_x = dpi_x / pt_per_inch / frac_pt;
        const final_frac_y = dpi_y / pt_per_inch / frac_pt;

        const xpos = x + (cursor_x + std.math.lossyCast(gl.Float, pos.x_offset)) * final_frac_x;
        const ypos = y + (cursor_y + std.math.lossyCast(gl.Float, pos.y_offset)) * final_frac_y;

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

        vbo.subData(0, gl.Float, &vertices);
        gl.drawArrays(.triangles, 0, 6);

        cursor_x += std.math.lossyCast(gl.Float, pos.x_advance);
        cursor_y += std.math.lossyCast(gl.Float, pos.y_advance);
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

    const monitor = glfw.Monitor.getPrimary().?;
    const phy_size = monitor.getPhysicalSize();
    std.debug.print("Physical Size: {}mx{}mm\n", .{ phy_size.width_mm, phy_size.height_mm });
    const video_mode = monitor.getVideoMode().?;
    std.debug.print("Video Mode: {}x{}@{}\n", .{ video_mode.getWidth(), video_mode.getHeight(), video_mode.getRefreshRate() });
    const mm_per_inch = 25.4;
    const dpi_x = intToGLFloat(video_mode.getWidth()) / intToGLFloat(phy_size.width_mm) * mm_per_inch;
    const dpi_y = intToGLFloat(video_mode.getHeight()) / intToGLFloat(phy_size.height_mm) * mm_per_inch;

    std.debug.print("DPI: {}x{}\n", .{ dpi_x, dpi_y });

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

    const face = try lib.createFaceMemory(@embedFile("./fonts/LxgwWenKai/LXGWWenKaiLite-Regular.ttf"), 0);
    defer face.deinit();

    try face.setCharSize(
        std.math.lossyCast(i32, font_pt * frac_pt),
        std.math.lossyCast(i32, font_pt * frac_pt),
        std.math.lossyCast(u16, dpi_x),
        std.math.lossyCast(u16, dpi_y),
    );

    const hb_face = harfbuzz.Face.fromFreetypeFace(face);
    defer hb_face.deinit();

    const hb_font = harfbuzz.Font.init(hb_face);
    defer hb_font.deinit();

    // We're using 1/64 pt as the unit here.
    hb_font.setScale(font_pt * frac_pt, font_pt * frac_pt);
    hb_font.setPTEM(font_pt);

    gl.pixelStore(.unpack_alignment, 1);

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

        try renderText(face, hb_font, shader_program, VBO, "你好，世界！—— “可以的”", 25.0, 400.0, za.Vec3.new(0.5, 0.8, 0.2), false, dpi_x, dpi_y);
        try renderText(face, hb_font, shader_program, VBO, "你好，世界！—— “可以的”", 25.0, 300.0, za.Vec3.new(0.5, 0.8, 0.2), true, dpi_x, dpi_y);

        window.swapBuffers();
        glfw.pollEvents();
    }
}
