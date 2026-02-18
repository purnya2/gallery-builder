const std = @import("std");
const builtin = @import("builtin");
const c = @import("sdl.zig").c;

const zigimg = @import("zigimg");

const utils = @import("utils.zig");
const errify = utils.errify;
const g = @import("globals.zig");
const ArrayList = std.ArrayList;

const MouseManager = @import("mouse.zig").MouseManager;
var m: MouseManager = .{};

const Camera2D = @import("camera2d.zig").Camera2D;
var camera: Camera2D = .{ .x = 0, .y = 0, .zoom = 1.0 };

var keys = struct {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
    zoom_in: bool = false,
    zoom_out: bool = false,
}{};

var selected_image_index = 0;
var image_is_selected = false;

pub fn sdlAppIterate(appstate: ?*anyopaque) !c.SDL_AppResult {
    _ = appstate;

    const now = c.SDL_GetTicks();
    const dt: f32 = @as(f32, @floatFromInt(now - g.last_tick)) / 1000.0;
    g.last_tick = now;

    const move_speed: f32 = 300.0;
    const zoom_speed: f32 = 0.8;

    // camera_movement
    if (keys.left) camera.x += move_speed * dt;
    if (keys.right) camera.x -= move_speed * dt;
    if (keys.up) camera.y += move_speed * dt;
    if (keys.down) camera.y -= move_speed * dt;
    if (keys.zoom_in) camera.zoom += zoom_speed * dt;
    if (keys.zoom_out) camera.zoom -= zoom_speed * dt;
    if (m.isLeftHolding() and m.isMoving()) {
        std.debug.print("Dragging at ({:.1}, {:.1})\n", .{ m.dx, m.dy });
        camera.x += m.dx;
        camera.y += m.dy;
    }
    camera.zoom += m.wheel_y / 100;
    _ = c.SDL_SetRenderDrawColorFloat(g.renderer, 255, 251, 246, c.SDL_ALPHA_OPAQUE_FLOAT);
    _ = c.SDL_RenderClear(g.renderer);

    // image behaviour

    var highest_index: usize = 0;
    var hovering: bool = false;
    image_is_selected = false;
    for (g.images.items, 0..) |*image, index| {
        const wrld_rect = c.SDL_FRect{
            .x = image.pos_x,
            .y = image.pos_y,
            .w = @floatFromInt(image.width),
            .h = @floatFromInt(image.height),
        };
        image.rect = camera_transformation(wrld_rect);

        if (m.mouse_x >= image.rect.x and
            m.mouse_x <= image.rect.x + image.rect.w and
            m.mouse_y >= image.rect.y and
            m.mouse_y <= image.rect.y + image.rect.h)
        {
            hovering = true;
            if (m.left_clicks == 1) {
                image_is_selected = true;

                if (highest_index < index) {
                    highest_index = index;
                }
            }
        } else {
            if (m.left_clicks == 1) {
                image.selected = false;
            }
        }
    }

    if (hovering) {
        _ = setCursorStyle(c.SDL_SYSTEM_CURSOR_POINTER);
    } else {
        _ = setCursorStyle(c.SDL_SYSTEM_CURSOR_DEFAULT);
    }

    // select/deselect only the top element among the clicked
    if (image_is_selected) {
        for (0..g.images.items.len) |index| {
            if (index == highest_index) {
                g.images.items[highest_index].selected = !g.images.items[highest_index].selected;
            } else {
                g.images.items[index].selected = false;
            }
        }
    }
    //show images
    for (g.images.items, 0..) |*image, index| {
        renderImage(image);
        _ = index;
    }
    _ = c.SDL_RenderPresent(g.renderer);

    //show gizmo
    //
    //
    if (image_is_selected) {
        renderGizmo(&g.images.items[highest_index]);
    }

    m.left_clicks = 0;
    m.dx = 0;
    m.dy = 0;
    m.wheel_y = 0;
    return c.SDL_APP_CONTINUE;
}

fn renderGizmo(image: *g.Image) void {
    _ = image;
}

fn renderImage(image: *g.Image) void {
    var outline_width: f32 = 2;
    if (image.selected) outline_width = 4;
    var outlinerect: c.SDL_FRect = .{
        .x = image.rect.x - outline_width,
        .y = image.rect.y - outline_width,
        .w = image.rect.w + outline_width * 2,
        .h = image.rect.h + outline_width * 2,
    };

    if (image.selected) {
        _ = c.SDL_SetRenderDrawColor(g.renderer, 0, 0, 255, c.SDL_ALPHA_OPAQUE);
    } else {
        _ = c.SDL_SetRenderDrawColor(g.renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE);
    }

    _ = c.SDL_RenderFillRect(g.renderer, &outlinerect);
    _ = c.SDL_RenderTexture(g.renderer, image.texture, null, &image.rect);
}
fn camera_transformation(dstrect: c.SDL_FRect) c.SDL_FRect {
    var win_w: i32 = 0;
    var win_h: i32 = 0;
    _ = c.SDL_GetWindowSize(g.window, &win_w, &win_h);
    const center_x: f32 = @as(f32, @floatFromInt(win_w)) / 2;
    const center_y: f32 = @as(f32, @floatFromInt(win_h)) / 2;

    const world_x = dstrect.x + camera.x;
    const world_y = dstrect.y + camera.y;

    const zoomed_x = center_x + (world_x - center_x) * camera.zoom;
    const zoomed_y = center_y + (world_y - center_y) * camera.zoom;

    return c.SDL_FRect{
        .x = zoomed_x,
        .y = zoomed_y,
        .w = dstrect.w * camera.zoom,
        .h = dstrect.h * camera.zoom,
    };
}

pub fn sdlAppEvent(appstate: ?*anyopaque, event: *c.SDL_Event) !c.SDL_AppResult {
    _ = appstate;
    const now = c.SDL_GetTicks();
    switch (event.type) {
        c.SDL_EVENT_QUIT => {
            return c.SDL_APP_SUCCESS;
        },
        c.SDL_EVENT_KEY_DOWN, c.SDL_EVENT_KEY_UP => {
            const down = event.type == c.SDL_EVENT_KEY_DOWN;
            switch (event.key.scancode) {
                c.SDL_SCANCODE_UP => keys.left = down,
                c.SDL_SCANCODE_RIGHT => keys.right = down,
                c.SDL_SCANCODE_LEFT => keys.up = down,
                c.SDL_SCANCODE_DOWN => keys.down = down,
                c.SDL_SCANCODE_EQUALS => keys.zoom_in = down,
                c.SDL_SCANCODE_MINUS => keys.zoom_out = down,
                c.SDL_SCANCODE_ESCAPE => return c.SDL_APP_SUCCESS,
                else => {},
            }
        },
        c.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            m.last_x = event.button.x;
            m.last_y = event.button.y;

            switch (event.button.button) {
                c.SDL_BUTTON_LEFT => {
                    m.left_down = true;
                    m.press_x = event.button.x;
                    m.press_y = event.button.y;
                    m.left_press_time = now;
                },
                c.SDL_BUTTON_RIGHT => {
                    m.right_down = true;
                    m.right_press_time = now;
                },
                c.SDL_BUTTON_MIDDLE => {
                    m.middle_down = true;
                },
                else => {},
            }
        },
        c.SDL_EVENT_MOUSE_BUTTON_UP => {
            switch (event.button.button) {
                c.SDL_BUTTON_LEFT => {
                    m.left_down = false;
                    const hold_time = now - m.left_press_time;

                    if (hold_time < m.click_threshold) { // click
                        if (now - m.last_click_time < m.double_clock_threshold) {
                            m.left_clicks = 2;
                        } else {
                            m.left_clicks = 1;
                        }

                        m.last_click_time = now;
                    } else { // hold/release
                        m.left_clicks = 0;
                    }
                },
                c.SDL_BUTTON_RIGHT => {
                    m.right_down = false;
                },
                c.SDL_BUTTON_MIDDLE => {
                    m.middle_down = false;
                },
                else => {},
            }
        },
        c.SDL_EVENT_MOUSE_MOTION => {
            m.dx = event.motion.x - m.last_x;
            m.dy = event.motion.y - m.last_y;
            m.last_x = event.motion.x;
            m.last_y = event.motion.y;
        },
        c.SDL_EVENT_MOUSE_WHEEL => {
            m.wheel_y = event.wheel.y;
        },

        else => {},
    }
    _ = c.SDL_GetMouseState(&m.mouse_x, &m.mouse_y);

    return c.SDL_APP_CONTINUE;
}
fn setCursorStyle(style: c.SDL_SystemCursor) void {
    const cursor = c.SDL_CreateSystemCursor(style);
    _ = c.SDL_SetCursor(cursor);
}
