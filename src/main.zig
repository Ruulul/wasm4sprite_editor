const std = @import("std");
const w4 = @import("wasm4.zig");

const Mode = enum {
    @"1BBP",
    @"2BBP",
    fn next(self: Mode) Mode {
        return switch(self) {
            .@"1BBP" => .@"2BBP",
            .@"2BBP" => .@"1BBP",
        };
    }
};
const Size = enum(usize) {
    x8 = 8,
    x16 = 16,
    x32 = 32,
    x64 = 64,
    fn next(self: Size) Size {
        return switch(self) {
            .x8 => .x16,
            .x16 => .x32,
            .x32 => .x64,
            .x64 => .x8,
        };
    }
    fn factor(self: Size) i32 {
        return switch(self) {
            .x64 => 2,
            .x32 => 4,
            .x16 => 8,
            .x8 => 16,
        };
    }
};
const Selection = enum {
    mode,
    size,
    tile,
    fn next(self: Selection) Selection {
        return switch (self) {
            .mode => .size,
            .size => .tile,
            .tile => .mode,
        };
    }
    fn prev(self: Selection) Selection {
        return switch (self) {
            .mode => .tile,
            .tile => .size,
            .size => .mode,

        };
    }
};
var mode: Mode = .@"1BBP";
var size: Size = .x8;
var selection: Selection = .mode;
var tile: usize = 0;
var buffer = [_]u2{ 0 } ** (64 * 64);
var frame: u64 = 0;

const rusty_palette = .{
    0x000000,
    0x503636,
    0x9b8b8b,
    0xffffff,
}; // https://lospec.com/palette-list/rusty-metal-g

export fn start() void {
    w4.PALETTE.* = rusty_palette;
}

var prev_input: u8 = 0;
var prev_mouse: u8 = 0;
fn handleInput() void {
    const input = w4.GAMEPAD1.*;
    defer prev_input = input;
    const mouse = w4.MOUSE_BUTTONS.*;
    defer prev_mouse = mouse;
    const just_pressed = (prev_input ^ input) & input;
    const just_pressed_mouse = (prev_mouse ^ mouse) & mouse;
    if (just_pressed & w4.BUTTON_DOWN != 0) selection = selection.next();
    if (just_pressed & w4.BUTTON_UP != 0) selection = selection.prev();
    if (just_pressed & w4.BUTTON_RIGHT != 0) tile +%= 1;
    if (just_pressed & w4.BUTTON_LEFT != 0) tile -%= 1;
    
    if (just_pressed & w4.BUTTON_2 != 0) {
        switch (selection) {
            .mode => mode = mode.next(),
            .size => size = size.next(),
            else => {
                buffer[tileIndex()] +%= 1;
                if (mode == .@"1BBP") buffer[tileIndex()] %= 2;
            },
        }
    }

    if (just_pressed_mouse & w4.MOUSE_LEFT != 0) {
        const x = normalizeCoord(w4.MOUSE_X.*);
        const y = normalizeCoord(w4.MOUSE_Y.*);
        if (x < 16 or y < 24) return;
        const x_with_offset: usize = @intCast(x - 16);
        const y_with_offset: usize = @intCast(y - 24);
        
        const side = @intFromEnum(size);
        const x_tile = @divTrunc(x_with_offset, @as(usize, @intCast(size.factor())));
        const y_tile = @divTrunc(y_with_offset, @as(usize, @intCast(size.factor())));
        const index = x_tile + y_tile * side;
        buffer[index] +%= 1;
        if (mode == .@"1BBP") buffer[index] %= 2;
    }
}

export fn update() void {
    frame += 1;
    handleInput();
    checkSelection(.mode);
    w4.textPrint(2, "Mode: {s}", 3, 3, .{@tagName(mode)}) catch {};
    checkSelection(.size);
    w4.textPrint(2, "Size: {s}", 3, 13, .{@tagName(size)}) catch {};
    checkSelection(.tile);
    const factor = size.factor();
    const side = @intFromEnum(size);
    for (0..side) |x| for (0..side) |y| {
        const x_offset: i32 = @intCast(x);
        const y_offset: i32 = @intCast(y);
        
        w4.DRAW_COLORS.* = @as(u16, switch (mode) {
            .@"1BBP" => buffer[x + y * side] % 2,
            .@"2BBP" => buffer[x + y * side],
        }) + 1;

        w4.rect(16 + x_offset * factor, 24 + y_offset * factor, @as(u32, @intCast(factor)), @as(u32, @intCast(factor)));
    };
    w4.DRAW_COLORS.* = 0x40;
    w4.rect(15, 23, 129, 129);
    w4.DRAW_COLORS.* = 0x2;
}

fn checkSelection(to_check: Selection) void {
    w4.DRAW_COLORS.* = if (selection == to_check)
        0x3
    else
        0x2;
}

fn isTile(x: usize, y: usize) bool {
    const side = @intFromEnum(size);
    return (tile % (side * side)) == (x + y * side);
}
fn tileIndex() usize {
    const side = @intFromEnum(size);
    return tile % (side * side);
}

fn normalizeCoord(n: i16) i32 {
    return @divTrunc(n * 2, 3);
}