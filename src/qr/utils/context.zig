const std = @import("std");
const testing = std.testing;

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

    pub fn gai(self: *Context, comptime T: type, n: usize, zero: T) ![]T {
        var a = try self.ga().alloc(T, n);
        var i: usize = 0;
        while (i < a.len) : (i += 1) {
            a[i] = zero;
        }
        return a;
    }
};

test "initialize zero" {
    var ctx = Context.init(std.testing.allocator);
    defer ctx.deinit();

    var one = try ctx.gai(u8, 1, 0);
    testing.expectEqual(one[0], 0);

    var two = try ctx.gai(u8, 2, 2);
    testing.expectEqual(two[1], 2);
}
