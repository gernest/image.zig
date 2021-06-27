const std = @import("std");
const Context = @import("./memory.zig");
const IllegalArgument = @import("./exceptions.zig").IllegalArgument;
const BitArray = @import("./bit_array.zig");

const math = std.math;

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

pub fn deinit(self: *Self) void {
    self.ctx.ga().free(self.bits);
}

pub fn index(self: *Self, x: usize, y: usize) usize {
    return y * self.row_size + @divTrunc(x, 32);
}

pub fn get(self: *Self, x: usize, y: usize) bool {
    if (x >= self.width or y >= self.height) return false;
    const offset = self.index(x, y);
    return std.math.shr(u32, self.bits[offset], @intCast(u32, @mod(x, 32)) & 1) != 0;
}

pub fn set(self: *Self, x: usize, y: usize) void {
    self.bits[self.index(x, y)] |= self.value(x);
}

pub fn unset(self: *Self, x: usize, y: usize) void {
    self.bits[self.index(x, y)] &= ~self.value(x);
}

pub fn flip(self: *Self, x: usize, y: usize) void {
    self.bits[self.index(x, y)] ^= self.value(x);
}

pub fn value(self: *Self, x: usize) u32 {
    return @intCast(u32, math.shl(usize, 1, @mod(x, 32)));
}

pub fn flipAll(self: *Self) void {
    var i: usize = 0;
    while (i < self.bits.len) : (i += 1) {
        self.bits[i] = ~self.bits[i];
    }
}

pub fn xor(self: *Self, mask: *Self) IllegalArgument!void {
    if (self.width != mask.width or self.height != mask.height or
        self.row_size != mask.row_size)
    {
        return error.MismatchInputDimension;
    }
    var y: usize = 0;
    while (y < self.height) : (y += 1) {
        const self_offset = y * self.row_size;
        const mask_offset = y * mask.row_size;
        var x: uszie = 0;
        while (x < self.row_size) : (x += 1) {
            self.bits[self_offset + x] ^= mask.bits[mask_offset + x];
        }
    }
}

pub fn clear(self: *Self) void {
    var i: usize = 0;
    while (i < self.bits.len) : (i += 1) {
        self.bits[i] = 0;
    }
}

pub fn setRegion(
    self: *Self,
    left: usize,
    top: usize,
    width: usize,
    height: usize,
) IllegalArgument!void {
    if (height < 1 or width < 1) return error.WrongDimension;
    const right = left + width;
    const bottom = top + height;
    if (bottom > self.height or right > self.width) return error.UnfitRegion;
    var y = top;
    while (y < bottom) : (y += 1) {
        var x = left;
        while (x < righ) : (x += 1) {
            self.bits[self.index(x, y)] |= self.value(x);
        }
    }
}

pub fn setRow(self: *Self, y: usize, row: *BitArray) void {
    const offset = y * self.row_size;
    std.mem.copy(u32, self.bits[offset .. offset + self.row_size], row.bits);
}
