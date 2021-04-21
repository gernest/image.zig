const std = @import("std");

const Context = struct {
    heap: *std.mem.Allocator,
    arena: std.heap.ArenaAllocator,

    pub fn init(a: *std.mem.Allocator) Context {
        return Context{
            .heap = a,
            .arena = std.heap.ArenaAllocator.init(a),
        };
    }

    pub fn ga(self: *Context) *std.mem.Allocator {
        return &self.arena.allocator;
    }

    pub fn deinit(self: Context) void {
        self.arena.deinit();
    }
};
