const std = @import("std");
const Context = @import("./memory.zig");
const IllegalArgument = @import("./exceptions.zig").IllegalArgument;

width: usize,
height: usize,
row_size: usize,
ctx: *Context,
bits: []u32,

const Self = @This();
const InitError = std.mem.Allocator.Error || IllegalArgument;

pub fn init(ctx: *Context, width: usize, height: usize) InitError!Self {
    if (width < 1 or height < 1) return error.WrongDimension;
    const row_size = @divTrunc(width + 31, 32);
    var bits = try ctx.ga().alloc(u32, row_size);
    return .{
        .width = width,
        .height = height,
        .row_size = row_size,
        .ctx = ctx,
        .bits = bits,
    };
}

pub fn initSquare(ctx: *Context, dimesnion: usize) InitError!Self {
    return init(ctx, dimension, dimension);
}

pub fn get(self: *Self, x: usize, y: usize) bool {
    if (x >= self.width or y >= self.height) return false;
    const offset = y * self.row_size + @divTrunc(x, 32);
    return std.math.shr(u32, self.bits[offset], @intCast(u32, @mod(x, 32)) & 1) != 0;
}
