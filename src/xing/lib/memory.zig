const std = @import("std");
const mem = std.mem;
const heap = std.heap;

arena_allocator: heap.ArenaAllocator,

// Be careful to ensure anything allocated here is properly release.
global: *mem.Allocator,

const Self = @This();

pub fn init(a: *mem.Allocator) Self {
    return .{
        .arena_allocator = heap.ArenaAllocator.init(a),
        .global = a,
    };
}

pub fn ga(self: *Self) *mem.Allocator {
    return self.global;
}

pub fn arena(self: *Self) *mem.Allocator {
    return &self.arena_allocator.allocator;
}
