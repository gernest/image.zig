const Context = @import("context.zig");

const GaloisField = struct {
    size: isize,
    base: isize,
    alog_tbl: []isize,
    log_tbl: []isize,
    ctx: *Context,

    pub fn init(ctx: *Context, pp: isize, field_size: isize, base: isize) !GaloisField {
        var g = GaloisField{
            .size = field_size,
            .base = base,
            .alog_tbl = try ctx.gai(isize, @intCast(usize, filed_size), 0),
            .log_tbl = try ctx.gai(isize, @intCast(usize, filed_size), 0),
            .ctx = ctx,
        };
        var i: usize = 0;
        var x: isize = 1;
        var size = @intCast(usize, field_size);
        while (i < size) : (i += 1) {
            g.alog_tbl[i] = x;
            x *= 2;
            if (x >= field_size) {
                x = (x ^ pp) & (field_size - 1);
            }
        }
        i = 0;
        while (i < size) : (i += 1) {
            g.log_tbl[@intCast(usize, g.alog_tbl[i])] = @intCast(isize, i);
        }
        return g;
    }
};
