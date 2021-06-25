const std = @import("std");
const mem = std.mem;
const heap = std.heap;

arena_allocator: heap.ArenaAllocator,

// Be careful to ensure anything allocated here is properly release.
global: *mem.Allocator,

const Self = @This();

fn ga(self: *Self) *mem.Allocator {
    return self.global;
}

fn arena(self: *Self) *mem.Allocator {
    return &self.arena_allocator.allocator;
}
