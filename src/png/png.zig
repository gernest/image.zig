const std = @import("std");
const image = @import("../image.zig");

const io = std.io;

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

const ColorType = enum {
    Grayscale = 0,
    TrueColor = 2,
    Paletted = 3,
    GrayscaleAlpha = 4,
    TrueColorAlpha = 6,
};

const ColorDepth = enum {
    Invalid,
    G1,
    G2,
    G4,
    G8,
    GA8,
    TC8,
    P1,
    P2,
    P4,
    P8,
    TCA8,
    G16,
    GA16,
    TC16,
    TCA16,

    fn palleted(v: ColorDepth) bool {
        const x = @enumToInt(ColorDepth{.P1});
        const y = @enumToInt(ColorDepth{.P8});
        const z = @enumToInt(v);
        return x <= z and z <= y;
    }
};

const Filter = enum {
    None,
    Sub,
    Up,
    Average,
    Paeth,
    NFilter,
};

const Interlace = enum {
    None,
    Adam7,
};

const interlaceScan = struct {
    xf: isize,
    yf: isize,
    xo: isize,
    yo: isize,

    fn init(xf: isize, yf: isize, xo: isize, yo: isize) interlaceScan {
        return .{
            .xf = xf,
            .yf = yf,
            .xo = xo,
            .yo = yo,
        };
    }
};

const interlacing = [_]interlaceScan{
    interlaceScan.init(8, 8, 0, 0),
    interlaceScan.init(8, 8, 4, 0),
    interlaceScan.init(4, 8, 0, 4),
    interlaceScan.init(4, 4, 2, 0),
    interlaceScan.init(2, 4, 0, 2),
    interlaceScan.init(2, 2, 1, 0),
    interlaceScan.init(1, 2, 0, 1),
};

const DecodingStage = enum {
    Start,
    SeenIHDR,
    SeenPLTE,
    SeentRNS,
    SeenIDAT,
    SeenIEND,
};

const png_header = "\x89PNG\r\n\x1a\n";

fn PNGReader(comptime ReaderType: type) type {
    return struct {
        r: ReaderType,
        image: image.Image,
        crc: std.hash.Crc32 = std.hash.Crc32.init(),
        width: usize,
        height: usize,
        depth: usize,
        palette: image.Color.Palette,
        cb: usize,
        stage: usize = 0,
        idat_lenght: u32 = 0,
        tmp: [3 * 256]u8 = []u8{0} ** 3 * 256,
        interlace: usize = 0,
        use_transparent: bool = false,
        transparent: [8]u8 = []u8{0} ** 8,

        const Self = @This();
        pub const Error = ReaderType.Error;
        pub const Reader = io.Reader(*Self, Error, read);

        pub fn rea(self: Self, buffer: []u8) Error!usize {
            if (buffer.len == 0) return 0;
        }
    };
}
