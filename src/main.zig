const w4 = @import("wasm4.zig");

export fn start() void {}

export fn update() void {
    w4.rect(
        @divTrunc(w4.MOUSE_X.* * 2, 3) - 4,
        @divTrunc(w4.MOUSE_Y.* * 2, 3) - 4,
        8,
        8,
    );
}
