// REF:
// https://github.com/Flecart/zig-learnopengl/blob/main/src/chapter-1/1.2.zig

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");

const log = std.log.scoped(.triangle);

fn glGetProcAddress(_: glfw.GLProc, proc: [:0]const u8) ?gl.binding.FunctionPointer {
    return glfw.getProcAddress(proc);
}

pub fn main() !void {
    if (!glfw.init(.{})) {
        log.err("Failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // some how type inference for window won't work with zls
    const window: glfw.Window = glfw.Window.create(800, 600, "Hello, OpenGL + GLFW!", null, null, .{
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

    while (!window.shouldClose()) {
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }
        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(.{ .color = true });
        window.swapBuffers();
        glfw.pollEvents();
    }
}
