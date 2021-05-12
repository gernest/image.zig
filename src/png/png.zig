const std = @import("std");

fn paeth(a: u8, b: u8, c: u8) u8 {
    const pc = @intCast(isize, c);
    const pa = @intCast(isize, b) - pc;
    const pb = @intCast(isize, a) - pc;

    const ppc = std.math.absCast(pa + pb);
    const ppa = std.math.absCast(pa);
    const ppb = std.math.absCast(pb);
    if (ppa <= pb and ppa <= pc) {
        return a;
    } else if (ppb <= ppc) {
        return b;
    }
    return c;
}

fn filterPaeth(cdat: []u8, cdat: []u8, bytes_per_pixel: usize) void {
    var a: isize = 0;
    var b: isize = 0;
    var c: isize = 0;

    var pa: usize = 0;
    var pb: usize = 0;
    var pc: usize = 0;

    var i: usize = 0;
    while (i < byte_per_pixel) : (i += 1) {
        a = 0;
        c = 0;
        var j: usize = 0;
        while (j < cdat.len) : (j += bytes_per_pixel) {
            b = @intCast(isize, pdat[j]);
            pc = std.math.absCast((b - c) + (a - c));
            pa = std.math.absCast(b - c);
            pb = std.math.absCast(a - c);
            if (pa <= pb and pa <= pc) {} else if (pb <= pc) {
                a = b;
            } else {
                a = c;
            }
            a += @intCast(isize, cdat[j]);
            a &= 0xff;
            cdat[j] = @truncate(u8, @bitCast(usize, a));
            c = b;
        }
    }
}
