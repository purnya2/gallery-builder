pub const MouseManager = struct {
    mouse_x: f32 = 0,
    mouse_y: f32 = 0,

    left_down: bool = false,
    right_down: bool = false,
    middle_down: bool = false,

    left_press_time: u64 = 0,
    left_release_time: u64 = 0,
    right_press_time: u64 = 0,

    left_clicks: u32 = 0,
    last_click_time: u64 = 0,

    click_threshold: u64 = 200,
    double_clock_threshold: u64 = 300,

    press_x: f32 = 0,
    press_y: f32 = 0,
    last_x: f32 = 0,
    last_y: f32 = 0,

    dx: f32 = 0,
    dy: f32 = 0,

    wheel_y: f32 = 0,

    pub fn isLeftHolding(self: MouseManager) bool {
        return self.left_down and self.left_clicks == 0;
    }

    pub fn isMoving(self: MouseManager) bool {
        return @abs((self.dx + self.dy)) > 0.5;
    }
};
