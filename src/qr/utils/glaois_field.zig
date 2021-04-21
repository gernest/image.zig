const Context = @import("context.zig");

const GaloisField = struct {
    size: isize,
    base: isize,
    alog_tbl: []isize,
    log_tbl: []isize,
    pub fn init(ctx: *Context, pp: isize, field_size: isize, b: isize) !GaloisField {}
};
