const std = @import("std");
const image = @import("../image.zig");

const io = std.io;
const mem = std.mem;

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

const ColorType = enum(u8) {
    Grayscale = 0,
    TrueColor = 2,
    Paletted = 3,
    GrayscaleAlpha = 4,
    TrueColorAlpha = 6,

    fn match(value: u8, e: ColorType) bool {
        return value == @enumToInt(e);
    }
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

const Interlace = enum(u8) {
    None,
    Adam7,

    fn match(value: u8, e: Interlace) bbool {
        return value == @enumToInt(e);
    }
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
        img: image.Image = undefined,
        crc: std.hash.Crc32 = std.hash.Crc32.init(),
        width: usize = 0,
        height: usize = 0,
        depth: usize = 0,
        // pre allocated pallete array for this instance
        palette_array: image.Color.Palette = comptime {
            var ls: [256]image.Color = undefined;
            return .{
                .colors = ls[0..],
            };
        },
        palette: image.Color.Palette,
        cb: ColorDepth = .Invalid,
        stage: DecodingStage = .Start,
        idat_lenght: u32 = 0,
        tmp: [3 * 256]u8 = []u8{0} ** 3 * 256,
        interlace: Interlace = .None,
        use_transparent: bool = false,
        transparent: [8]u8 = []u8{0} ** 8,

        const Self = @This();

        pub const Error = ReaderType.Error || error{
            NoEnoughPixelData,
            InvalidChecksum,
        };

        pub const Reader = io.Reader(*Self, Error, read);

        pub const zlib = std.compress.zlib.ZlibStream(Reader);

        pub fn init(r: ReaderType) Self {
            return .{ .r = r };
        }

        pub fn reader(Self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0) return 0;
            while (self.idat_lenght == 0) {
                try self.verifyChecksum();
                d.idat_lenght = try self.r.readIntBig(u32);
                try self.r.readNoEof(self.tmp[0..4]);
                if (!mem.eql(u8, sel.tmp[0..4], "IDAT")) {
                    return error.NoEnoughPixelData;
                }
                self.crc.crc = 0xffffffff;
                self.crc.update(self.tmp[0..4]);
            }
            const n = try self.r.readNoEof(p[0..min(p.len, @intCast(usize, self.idat_lenght))]);
            self.crc.update(p[0..n]);
            self.idat_lenght -= @intCast(usize, n);
            return n;
        }

        fn min(a: usize, b: usize) usize {
            if (a < b) {
                return a;
            }
            return b;
        }

        fn verifyChecksum(self: *Self) !void {
            const n = try self.r.readIntBig(u32);
            if (n != self.crc.final()) {
                return error.InvalidChecksum;
            }
        }

        fn checkHeader(self: Self) !void {
            _ = try self.r.readNoEof(self.tmp[0..png_header.len]);
            if (!mem.eql(u8, self.tmp[0..png_header.len], png_header)) {
                return error.NotPNGFile;
            }
        }

        fn parseIHDR(self: *Self, length: u32s) !void {
            if (length != 13) {
                return error.BadIHDRLength;
            }
            _ = try self.r.readNoEof(self.tmp[0..13]);
            self.crc.update(self.tmp[0..13]);
            if (Self.tmp[11] != 0) {
                return error.UnsupportedFilterMethod;
            }
            if (!Interlace.match(sellf.tmp[12], .None) and
                !Interlace.match(sellf.tmp[12], .Adam7))
            {
                return error.InvalidInterlaceMethod;
            }
            self.interlace = @intToEnum(Interlace, self.tmp[12]);
            const w = mem.readIntBig(i32, self.tmp[0..4]);
            const h = mem.readIntBig(i32, self.tmp[4..8]);
            if (w < 0 or h < 0) {
                return error.NonPositiveDimension;
            }
            const n_pixel_64 = @intCast(i64, w) * @intCast(i64, h);
            const n_pixel = @truncate(isize, n_pixel_64);
            if (n_pixel_64 != @intCast(i64, n_pixel)) {
                return error.DimensionOverflow;
            }
            if (n_pixel != @divTrunc(n_pixel * 8, 8)) {
                return error.DimensionOverflow;
            }
            self.cb = .Invalid;
            self.depth = @intCast(usize, self.tmp[8]);
            if (self.depth == 1) {
                if (ColorType.match(self.tmp[9], .Grayscale)) {
                    self.cb = .G1;
                } else if (ColorType.match(self.tmp[9], .Paletted)) {
                    self.cb = .P1;
                }
            } else if (self.depth == 2) {
                if (ColorType.match(self.tmp[9], .Grayscale)) {
                    self.cb = .G2;
                } else if (ColorType.match(self.tmp[9], .Paletted)) {
                    self.cb = .P2;
                }
            } else if (self.depth == 4) {
                if (ColorType.match(self.tmp[9], .Grayscale)) {
                    self.cb = .G4;
                } else if (ColorType.match(self.tmp[9], .Paletted)) {
                    self.cb = .P4;
                }
            } else if (self.depth == 8) {
                if (ColorType.match(self.tmp[9], .Grayscale)) {
                    self.cb = .G8;
                } else if (ColorType.match(self.tmp[9], .TrueColor)) {
                    self.cb = .TC8;
                } else if (ColorType.match(self.tmp[9], .Paletted)) {
                    self.cb = .P8;
                } else if (ColorType.match(self.tmp[9], .GrayscaleAlpha)) {
                    self.cb = .GA8;
                } else if (ColorType.match(self.tmp[9], .TrueColorAlpha)) {
                    self.cb = .TCA8;
                }
            } else if (self.depth == 16) {
                if (ColorType.match(self.tmp[9], .Grayscale)) {
                    self.cb = .G16;
                } else if (ColorType.match(self.tmp[9], .TrueColor)) {
                    self.cb = .TC16;
                } else if (ColorType.match(self.tmp[9], .GrayscaleAlpha)) {
                    self.cb = .GA16;
                } else if (ColorType.match(self.tmp[9], .TrueColorAlpha)) {
                    self.cb = .TCA16;
                }
            }
            if (self.cb == .Invalid) {
                return error.UnsupportedBitDepthColorType;
            }
            self.width = @truncate(usize, w);
            self.height = @truncate(usize, h);
            return self.verifyChecksum();
        }

        fn parseChunk(self: Self) !void {}

        pub fn decode(self: *Self, a: *mem.Allocator) !image.Image {
            const r = try zlib.init(a, self.reader());
            defer r.deinit();
            var img: image.Image = undefined;
            switch (self.interface) {
                .None => {
                    img = self.readImagePass(r.reader(), 0, false);
                },
                .Adam7 => {
                    img = try self.readImagePass(null, 0, false);
                },
            }
            // Check for EOF, to verify the zlib checksum.
            var n: usize = 0;
            var i: usize = 0;
            while (true) : (i += 1) {
                if (i == 100) {
                    return error.NoProgress;
                }
                n = self.read(self.tmp[0..1]);
                if (n == 0) {
                    // we have reached EndOfStream
                    if (self.idat_lenght > 0) {
                        return error.TooMuchPixelData;
                    }
                    break;
                }
            }
            return img;
        }
        fn readImagePass(self: Self, r: ?Reader, pass: usize, allocate_only: bool) !image.Image {}
    };
}
// decodePNG reads a PNG image from r and returns it as an image.Image.
// The type of Image returned depends on the PNG contents.
pub fn decodePNG(ReaderType: anytype) !image.Image {
    const r = PNGReader(@TypeOf(ReaderType)).init(ReaderType);
    try r.checkHeader();
    while (r.stage != .SeenIEND) {
        try r.parseChunk();
    }
    return r.img;
}
