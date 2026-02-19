const std = @import("std");
const ArrayList = std.ArrayList;
const c = @import("sdl.zig").c;

pub var gpa = std.heap.page_allocator;

pub var last_tick: u64 = 0;

pub var window: ?*c.SDL_Window = undefined;
pub var renderer: ?*c.SDL_Renderer = undefined;

pub var sounds_spec: c.SDL_AudioSpec = undefined;
pub var sounds_data: []u8 = undefined;
pub var audio_device: c.SDL_AudioDeviceID = undefined;

pub var audio_streams_buf: [8]?*c.SDL_AudioStream = undefined;
pub var audio_streams: []?*c.SDL_AudioStream = audio_streams_buf[0..0];

pub var window_width: i32 = 1280;
pub var window_height: i32 = 720;

pub var images: ArrayList(Image) = std.ArrayListUnmanaged(Image){};

pub const Image = struct { texture: *c.SDL_Texture, rect: c.SDL_FRect = undefined, width: i32, height: i32, scale: f32 = 1, pos_x: f32, pos_y: f32, z_index: usize = 0, selected: bool };
