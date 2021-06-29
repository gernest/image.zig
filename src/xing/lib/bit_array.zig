const Context = @import("./memory.zig");
const std = @import("std");
const math = std.math;
const testing = std.testing;

const DynamicBitSet = std.bit_set.DynamicBitSet;
const DynamicBitSetUnmanaged = std.bit_set.DynamicBitSetUnmanaged;
const MaskInt = DynamicBitSetUnmanaged.MaskInt;
const ShiftInt = DynamicBitSetUnmanaged.ShiftInt;

bit_set: DynamicBitSet,
ctx: *Context,

const Self = @This();

pub fn init(ctx: *Context, size: usize) !Self {
    return Self{
        .bit_set = try DynamicBitSet.initEmpty(size, ctx.ga()),
        .ctx = ctx,
    };
}

pub fn deinit(self: *Self) void {
    self.bit_set.deinit();
}

pub fn getSize(self: *Self) usize {
    return self.bit_set.capacity();
}

pub fn getSizeInBytes(self: *Self) usize {
    return @divTrunc(self.getSize() + 7, 8);
}

pub fn get(self: *Self, i: usize) bool {
    return self.bit_set.isSet(i);
}

pub fn set(self: *Self, i: usize) void {
    self.bit_set.set(i);
}

pub fn flip(self: *Self, i: usize) void {
    self.bit_set.toggle(i);
}

pub fn getNextSet(self: *Self, from: usize) usize {
    const size = self.getSize();
    if (from > size) return size;
    var it = self.bit_set.iterator(.{});
    while (it.next()) |idx| {
        if (idx >= from) {
            return idx;
        }
    }
    return size;
}

pub fn getNextUnSet(self: *Self, from: usize) usize {
    const size = self.getSize();
    if (from > size) return size;
    var it = self.bit_set.iterator(.{ .kind = .unset });
    while (it.next()) |idx| {
        if (idx >= from) {
            return idx;
        }
    }
    return size;
}

pub fn clear(self: *Self) void {}

pub fn setBullk(self: *Self, index: usize, new_bits: usize) void {}

pub fn ensureCapacity(self: *Self, size: usize) !void {
    if (size > numMasks(self.getSize()) * @bitSizeOf(MaskInt)) {
        try self.bit_set.resize(self.getSize() + size, false);
    }
}

pub fn appendBit(self: *Self, bit: bool) void {
    try self.bit_set.resize(self.bit_set.capacity() + 1, bool);
}

pub fn appendBits(self: *Self, value: u32, num_bits: usize) !void {
    var bits_left = num_bits;
    while (bits_left > 0) : (bits_left -= 1) {
        const v = (math.shr(usize, value, bits_left - 1) & 0x01) == 1;
        try self.appendBit(v);
    }
}

pub fn appendBiArray(self: *Self, other: *Self) !void {
    const size = self.bit_set.capacity();
    var i: usize = 0;
    while (i < size) : (i += 1) {
        try self.appendBit(other.get(i));
    }
}

pub fn xor(self: *Self, other: *Self) !void {
    const num_masks = numMasks(self.getSize());
    for (self.unmanaged.masks[0..num_masks]) |*mask, i| {
        mask.* ^= other.masks[i];
    }
}

pub fn getBits(self: *Self, other: *Self) ![]usize {
    const num_masks = numMasks(self.bit_set.unmanaged.bit_length);
    return self.unmanaged.masks[0..num_masks];
}

fn numMasks(bit_length: usize) usize {
    return (bit_length + (@bitSizeOf(MaskInt) - 1)) / @bitSizeOf(MaskInt);
}

test "TestBitArray_GetSize" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();
    {
        var a = try Self.init(&ctx, 0);
        defer a.deinit();
        try testing.expectEqual(@as(usize, 0), a.getSize());
    }
    {
        var a = try Self.init(&ctx, 8);
        defer a.deinit();
        try testing.expectEqual(@as(usize, 8), a.getSize());
        try testing.expectEqual(@as(usize, 1), a.getSizeInBytes());
    }
    {
        var a = try Self.init(&ctx, 9);
        defer a.deinit();
        try testing.expectEqual(@as(usize, 9), a.getSize());
        try testing.expectEqual(@as(usize, 2), a.getSizeInBytes());
    }
}

test "TestBitArray_EnsureCapacity" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    {
        var a = try Self.init(&ctx, 31);
        defer a.deinit();
        try a.ensureCapacity(30);

        try testing.expectEqual(@as(usize, 31), a.getSize());
        a.bit_set.unmanaged.masks[0] = 10;
        try a.ensureCapacity(33);
        try testing.expectEqual(@as(usize, 10), a.bit_set.unmanaged.masks[0]);
    }
}

test "TestBitArray_GetSetFlip" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    var a = try Self.init(&ctx, 5);
    defer a.deinit();

    a.set(3);
    try testing.expectEqual(true, a.get(3));

    a.flip(3);
    try testing.expectEqual(false, a.get(3));

    a.flip(3);
    try testing.expectEqual(true, a.get(3));
}

test "TestBitArray_GetNextSet" {
    var ctx = Context.init(testing.allocator);
    defer ctx.deinit();

    var a = try Self.init(&ctx, 65);
    defer a.deinit();

    a.set(10);
    a.set(33);

    try testing.expectEqual(@as(usize, 65), a.getNextSet(70));
    try testing.expectEqual(@as(usize, 10), a.getNextSet(3));
    try testing.expectEqual(@as(usize, 10), a.getNextSet(10));
    try testing.expectEqual(@as(usize, 33), a.getNextSet(11));
    try testing.expectEqual(@as(usize, 65), a.getNextSet(34));
}
