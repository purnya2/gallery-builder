const std = @import("std");
const builtin = @import("builtin");
const c = @import("sdl.zig").c;

const zigimg = @import("zigimg");

const utils = @import("utils.zig");
const errify = utils.errify;
const ErrorStore = utils.ErrorStore;

const render = @import("render.zig");
const g = @import("globals.zig");

const sdl_log = std.log.scoped(.sdl);

var fully_initialized = false;

var sprites_texture: *c.SDL_Texture = undefined;

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !c.SDL_AppResult {
    _ = appstate;
    _ = argv;
    g.last_tick = c.SDL_GetTicks();
    try errify(c.SDL_SetAppMetadata("just testing around bruh", "0.1", "com.testing.around"));

    try errify(c.SDL_Init(c.SDL_INIT_VIDEO));

    try errify(c.SDL_CreateWindowAndRenderer("testing", g.window_width, g.window_height, c.SDL_WINDOW_RESIZABLE, @ptrCast(&g.window), @ptrCast(&g.renderer)));
    errdefer c.SDL_DestroyWindow(g.window);
    errdefer c.SDL_DestroyRenderer(g.renderer);
    _ = c.SDL_SetRenderVSync(g.renderer, 1);

    try debug_loadimages();

    return c.SDL_APP_CONTINUE;
}

fn debug_loadimages() !void {
    const allocator = std.heap.page_allocator;

    const lajade = @embedFile("assets/testjade.jpg");
    const empanada = @embedFile("assets/empanada.jpg");

    var image = try zigimg.Image.fromMemory(allocator, lajade[0..]);
    var image2 = try zigimg.Image.fromMemory(allocator, empanada[0..]);
    defer image.deinit(allocator);
    defer image2.deinit(allocator);

    const sdl_format = try getSDLPixelFormat(image.pixels);
    const sdl_format2 = try getSDLPixelFormat(image2.pixels);

    const pitch = try getPitch(image);
    const pitch2 = try getPitch(image2);

    const surface: *c.SDL_Surface = try errify(c.SDL_CreateSurfaceFrom(@intCast(image.width), @intCast(image.height), @intCast(sdl_format), @ptrCast(image.pixels.asBytes()), @intCast(pitch)));
    const img_texture: *c.SDL_Texture = try errify(c.SDL_CreateTextureFromSurface(g.renderer, surface));
    const surface2: *c.SDL_Surface = try errify(c.SDL_CreateSurfaceFrom(@intCast(image2.width), @intCast(image2.height), @intCast(sdl_format2), @ptrCast(image2.pixels.asBytes()), @intCast(pitch2)));
    const img_texture2: *c.SDL_Texture = try errify(c.SDL_CreateTextureFromSurface(g.renderer, surface2));

    const item: g.Image = .{ .texture = img_texture, .width = @intCast(image.width), .height = @intCast(image.height), .scale = 1, .pos_x = 0, .pos_y = 0, .selected = false };
    const item2: g.Image = .{ .texture = img_texture2, .width = @intCast(image2.width), .height = @intCast(image2.height), .scale = 1, .pos_x = 500, .pos_y = 100, .selected = false };

    try g.images.append(g.gpa, item);
    try g.images.append(g.gpa, item2);
}

fn sdlAppEvent(appstate: ?*anyopaque, event: *c.SDL_Event) !c.SDL_AppResult {
    return render.sdlAppEvent(appstate, event);
}

fn sdlAppIterate(appstate: ?*anyopaque) !c.SDL_AppResult {
    return render.sdlAppIterate(appstate);
}

fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!c.SDL_AppResult) void {
    _ = appstate;

    _ = result catch |err| if (err == error.SdlError) {
        sdl_log.err("{s}", .{c.SDL_GetError()});
    };

    if (fully_initialized) {
        while (g.audio_streams.len != 0) {
            c.SDL_DestroyAudioStream(g.audio_streams[g.audio_streams.len - 1]);
            g.audio_streams.len -= 1;
        }
        c.SDL_CloseAudioDevice(g.audio_device);
        c.SDL_free(g.sounds_data.ptr);
        c.SDL_DestroyTexture(sprites_texture);
        c.SDL_DestroyRenderer(g.renderer);
        c.SDL_DestroyWindow(g.window);
        fully_initialized = false;
    }
}

fn getSDLPixelFormat(pixels: anytype) !c_int {
    return switch (pixels) {
        .rgb24 => c.SDL_PIXELFORMAT_RGB24,
        .rgba32 => c.SDL_PIXELFORMAT_ABGR8888,
        else => {
            std.debug.print("Formato non supportato: {s}\n", .{@tagName(pixels)});
            return error.UnsupportedImageFormat;
        },
    };
}

fn getPitch(image: anytype) !usize {
    return switch (image.pixels) {
        .rgb24 => image.width * 3,
        .rgba32 => image.width * 4,
        else => {
            std.debug.print("Formato non supportato: {s}\n", .{@tagName(image.pixels)});
            return error.UnsupportedImageFormat;
        },
    };
}
//#region SDL main callbacks boilerplate

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(c.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}

fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return c.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c.SDL_AppResult {
    return sdlAppInit(appstate.?, @ptrCast(argv.?[0..@intCast(argc)])) catch |err| app_err.store(err);
}

fn sdlAppIterateC(appstate: ?*anyopaque) callconv(.c) c.SDL_AppResult {
    return sdlAppIterate(appstate) catch |err| app_err.store(err);
}

fn sdlAppEventC(appstate: ?*anyopaque, event: ?*c.SDL_Event) callconv(.c) c.SDL_AppResult {
    return sdlAppEvent(appstate, event.?) catch |err| app_err.store(err);
}

fn sdlAppQuitC(appstate: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    sdlAppQuit(appstate, app_err.load() orelse result);
}

var app_err: ErrorStore = .{};

//#endregion SDL main callbacks boilerplate
