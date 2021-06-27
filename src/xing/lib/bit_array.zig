bits: []u32,
size: usize,

const Self = @This();

pub fn sizeInBytes(self: *Self) usize {}

pub fn clear(self: *Self) void {}

pub fn set(self: *Self, y: usize) void {}
