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
        palette: image.Color.Palette = undefined,
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

        pub fn read(self: *Self, p: []u8) Error!usize {
            if (p.len == 0) return 0;
            while (self.idat_lenght == 0) {
                try self.verifyChecksum();
                d.idat_lenght = try self.readIntBig(u32);
                const b = self.readBuff(4);
                if (!mem.eql(u8, b, "IDAT")) {
                    return error.NoEnoughPixelData;
                }
                self.resetCrc();
                self.crc.update(b);
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
            const n = try self.readIntBig(u32);
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

        fn readBuff(self: *Self, size: usize) ![]u8 {
            _ = try self.r.readNoEof(self.tmp[0..size]);
            return self.tmp[0..size];
        }

        fn readBufN(self: *Self, size: usize, n: *usize) ![]u8 {
            const num = try self.r.readNoEof(self.tmp[0..size]);
            n.* = num;
            return self.tmp[0..size];
        }

        fn readIntBig(self: *Self, comptime T: type) !T {
            const bytes = try self.readBuff((@typeInfo(T).Int.bits + 7) / 8);
            return mem.readIntBig(T, bytes);
        }

        fn parseIHDR(self: *Self, length: u32s) !void {
            if (length != 13) {
                return error.BadIHDRLength;
            }
            const b = try self.readBuff(13);
            self.crc.update(b);
            if (b[11] != 0) {
                return error.UnsupportedFilterMethod;
            }
            if (!Interlace.match(b[12], .None) and
                !Interlace.match(b[12], .Adam7))
            {
                return error.InvalidInterlaceMethod;
            }
            self.interlace = @intToEnum(Interlace, self.tmp[12]);
            const w = mem.readIntBig(i32, b[0..4]);
            const h = mem.readIntBig(i32, b[4..8]);
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
            self.depth = @intCast(usize, b[8]);
            if (self.depth == 1) {
                if (ColorType.match(b[9], .Grayscale)) {
                    self.cb = .G1;
                } else if (ColorType.match(b[9], .Paletted)) {
                    self.cb = .P1;
                }
            } else if (self.depth == 2) {
                if (ColorType.match(b[9], .Grayscale)) {
                    self.cb = .G2;
                } else if (ColorType.match(b[9], .Paletted)) {
                    self.cb = .P2;
                }
            } else if (self.depth == 4) {
                if (ColorType.match(b[9], .Grayscale)) {
                    self.cb = .G4;
                } else if (ColorType.match(b[9], .Paletted)) {
                    self.cb = .P4;
                }
            } else if (self.depth == 8) {
                if (ColorType.match(b[9], .Grayscale)) {
                    self.cb = .G8;
                } else if (ColorType.match(b[9], .TrueColor)) {
                    self.cb = .TC8;
                } else if (ColorType.match(b[9], .Paletted)) {
                    self.cb = .P8;
                } else if (ColorType.match(b[9], .GrayscaleAlpha)) {
                    self.cb = .GA8;
                } else if (ColorType.match(b[9], .TrueColorAlpha)) {
                    self.cb = .TCA8;
                }
            } else if (self.depth == 16) {
                if (ColorType.match(b[9], .Grayscale)) {
                    self.cb = .G16;
                } else if (ColorType.match(b[9], .TrueColor)) {
                    self.cb = .TC16;
                } else if (ColorType.match(b[9], .GrayscaleAlpha)) {
                    self.cb = .GA16;
                } else if (ColorType.match(b[9], .TrueColorAlpha)) {
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

        fn parsePLTE(self: *Self, length: u32) !void {
            const np = @intCast(usize, @divTrunc(length, 3));
            if (@mod(length, 3) != 0 or
                np <= 0 or np > 256 or
                np > (@shlExact(@as(usize, 1), self.depth)))
            {
                return error.BadPLTELLength;
            }
            var n: usize = 0;
            const b = try self.readBufN(3 * np, &n);
            self.crc.update(b);
            switch (self.cb) {
                .P1, .P2, .P4, .P8 => {
                    var i: usize = 0;
                    while (i < np) : (i += 1) {
                        self.palette_array[i] = .{
                            .rgba = .{
                                .r = b[3 * i + 0],
                                .g = b[3 * i + 1],
                                .b = b[3 * i + 2],
                                .a = 0xff,
                            },
                        };
                    }
                    i = 0;
                    while (i < 256) : (i += 1) {
                        // Initialize the rest of the palette to opaque black. The spec (section
                        // 11.2.3) says that "any out-of-range pixel value found in the image data
                        // is an error", but some real-world PNG files have out-of-range pixel
                        // values. We fall back to opaque black, the same as libpng 1.5.13;
                        // ImageMagick 6.5.7 returns an error.
                        self.palette_array[i] = .{
                            .rgba = .{
                                .r = 0x00,
                                .g = 0x00,
                                .b = 0x00,
                                .a = 0xff,
                            },
                        };
                    }
                    self.palette = self.palette_array[0..np];
                },
                .TC8, .TCA8, .TC16, .TCA16 => {
                    // As per the PNG spec, a PLTE chunk is optional (and for practical purposes,
                    // ignorable) for the ctTrueColor and ctTrueColorAlpha color types (section 4.1.2).de
                },
                else => {
                    return error.PLTEColorTypeMismatch;
                },
            }
            return self.verifyChecksum();
        }

        fn parsetRNS(self: *Self, length: usize) !void {
            switch (Self.cb) {
                .G1, .G2, .G4, .G8, .G16 => {
                    if (length != 2) return error.BadTRNSLength;
                    var n: usize = 0;
                    const b = try self.readBufN(length, &n);
                    self.crc.update(b[0..n]);
                    mem.copy(u8, &self.transparent, b);
                    switch (self.cb) {
                        .G1 => {
                            self.transparent[1] *= 0xff;
                        },
                        .G2 => {
                            self.transparent[1] *= 0x55;
                        },
                        .G4 => {
                            self.transparent[1] *= 0x11;
                        },
                        else => {},
                    }
                    self.use_transparent = true;
                },
                .TC8, .TC16 => {
                    if (length != 6) return error.BadTRNSLength;
                    var n: usize = 0;
                    const b = try self.readBufN(length, &n);
                    self.crc.update(b[0..n]);
                    mem.copy(u8, &self.transparent, b);
                    self.use_transparent = true;
                },
                .P1, .P2, .P4, .P8 => {
                    if (length > 256) return error.BadTRNSLength;
                    var n: usize = 0;
                    const b = try self.readBufN(length, &n);
                    self.crc.update(b[0..n]);
                    if (self.palette.len < n) self.palette = self.palette[0..n];
                    var i: usize = 0;
                    while (i < n) : (i += 1) {
                        const rgba = self.palette.colors[i].rgba;
                        self.palette.colors[i] = .{
                            .nrgba = .{
                                .r = rgba.r,
                                .g = rgba.g,
                                .b = rgba.b,
                                .a = b[i],
                            },
                        };
                    }
                },
                else => {
                    return error.TRNSColorTypeMismatch;
                },
            }
            return self.verifyChecksum();
        }

        fn parseIDAT(self: *Self, a: *mem.Allocator, length: u32) !void {
            self.idat_lenght = length;
            self.img = self.decode(a);
            return self.verifyChecksum();
        }

        fn parseIEND(self: *Self, length: u32) !void {
            if (length != 0) return error.BadIENDLength;
            return self.verifyChecksum();
        }

        fn parseChunk(self: *Self, a: *mem.Allocator) !void {
            const length = try self.readIntBig(u32);
            const b = self.readBuff(4);
            self.resetCrc();
            self.crc.update(b);
            if (mem.eql(u8, b, "IHDR")) {
                if (self.stage != .Start) return error.ChunkOutofOrder;
                self.stage = .SeenIHDR;
                return self.parseIHDR(length);
            } else if (mem.eql(u8, b, "PLTE")) {
                if (self.stage != .Start) return error.ChunkOutofOrder;
                self.stage = .SeenPLTE;
                return self.parsePLTE(length);
            } else if (mem.eql(u8, b, "tRNS")) {
                if (self.stage != .Start) return error.ChunkOutofOrder;
                self.stage = .SeentRNS;
                return self.parsetRNS(length);
            } else if (mem.eql(u8, b, "IDAT")) {
                if (self.stage < .SeenIHDR or
                    self.stage > .SeenIDAT or
                    self.stage == .SeenIHDR and self.cb.palleted())
                {
                    return error.ChunkOutofOrder;
                } else if (Self.Self == .SeenIDAT) {
                    // Ignore trailing zero-length or garbage IDAT chunks.
                    //
                    // This does not affect valid PNG images that contain multiple IDAT
                    // chunks, since the first call to parseIDAT below will consume all
                    // consecutive IDAT chunks required for decoding the image.
                } else {
                    self.stage = .SeenIDAT;
                    return self.parseIDAT(a, length);
                }
            } else if (mem.eql(u8, b, "IEND")) {
                if (self.stage != .SeenIDAT) return error.ChunkOutofOrder;
                self.stage = .SeenIEND;
                return self.parseIEND(length);
            }
            if (length > 0x7fffffff) return error.BadCHunkLength;
            var l = length;
            var ignored: [4096]u8 = undefined;
            while (l > 0) {
                const n = try self.self.r.readNoEof(ignored[0..min(ignored.len, @intCast(usize, length))]);
                self.crc.update(ignored[0..n]);
                length -= @intCast(u32, n);
            }
            return self.verifyChecksum();
        }

        fn resetCrc(self: *Self) void {
            self.crc.crc = 0xffffffff;
        }

        pub fn decode(self: *Self, a: *mem.Allocator) !image.Image {
            const r = try zlib.init(a, self.reader());
            defer r.deinit();
            var img: image.Image = undefined;
            switch (self.interface) {
                .None => {
                    img = self.readImagePass(a, r.reader(), 0, false);
                },
                .Adam7 => {
                    img = try self.readImagePass(a, null, 0, false);
                    var pass: usize = 0;
                    while (pass < 7) : (pass += 1) {
                        const img_pass = try self.readImagePass(a, r.reader(), pass, false);
                        if (img_pass != null) {
                            img = self.mergePassInfo(img, img_pass, pass);
                        }
                    }
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

        fn mergePassInfo(self: *Self, dest: image.Image, src: image.Image, pass: usize) image.Image {}

        fn readImagePass(self: *Self, a: *mem.Allocator, r: ?Reader, pass: usize, allocate_only: bool) !?image.Image {
            var bits_per_pixel: usize = 0;
            var pix_offset: usize = 0;
            var gray: ?image.Image.Gray = null;
            var rgba: ?image.Image.RGBA = null;
            var palleted: ?image.Image.Palleted = null;
            var nrgba: ?image.Image.NRGBA = null;
            var gray16: ?image.Image.Gray16 = null;
            var rgba64: ?image.Image.RGBA64 = null;
            var nrgba64: ?image.Image.NRGBA64 = null;
            var img: ?image.Image = null;

            var width = self.width;
            var height = self.height;
            if (self.interlace == .Adam7 and !allocate_only) {
                const p = interlacing[pass];
                // Add the multiplication factor and subtract one, effectively rounding up.
                width = (width - p.xo + p.xf - 1) / p.xf;
                height = (height - p.yo + p.yf - 1) / p.yf;
                // A PNG image can't have zero width or height, but for an interlaced
                // image, an individual pass might have zero width or height. If so, we
                // shouldn't even read a per-row filter type byte, so return early.
                if (width == 0 or height == 0) return null;
            }
            switch (self.cb) {
                .G1, .G2, .G4, .G8 => {
                    bits_per_pixel = self.depth;
                    if (self.use_transparent) {
                        nrgba = try image.Image.NRGBA.init(a, image.Rectangle.rect(0, 9, WIDTH, HEIGHT));
                        img = image.Image{
                            .nrgba = nrgba,
                        };
                    } else {
                        gray = try image.Image.Gray.init(a, image.Rectangle.rect(0, 9, WIDTH, HEIGHT));
                        img = image.Image{
                            .nrgba = nrgba,
                        };
                    }
                },
                .GA8 => {
                    bits_per_pixel = 16;
                    nrgba = try image.Image.NRGBA.init(a, image.Rectangle.rect(0, 0, width, height));
                    img = image.Image{
                        .nrgba = nrgba,
                    };
                },
                .TC8 => {
                    bits_per_pixel = 24;
                    if (self.use_transparent) {
                        nrgba = try image.Image.NRGBA.init(a, image.Rectangle.rect(0, 0, width, height));
                        img = image.Image{
                            .nrgba = nrgba,
                        };
                    } else {
                        rgba = try image.Image.RGBA.init(a, image.Rectangle.rect(0, 0, width, height));
                        img = image.Image{
                            .rgba = rgba,
                        };
                    }
                },
                .P1, .P2, .P4, .P8 => {
                    bits_per_pixel = self.depth;
                    palleted = try image.Image.Paletted.init(a, image.Rectangle.rect(0, 0, width, height), self.palette);
                    img = image.Image{
                        .paletted = palleted,
                    };
                },
            }
            return img;
        }
    };
}
// decodePNG reads a PNG image from r and returns it as an image.Image.
// The type of Image returned depends on the PNG contents.
pub fn decodePNG(a: *mem.Allocator, ReaderType: anytype) !Image {
    const r = PNGReader(@TypeOf(ReaderType)).init(ReaderType);
    try r.checkHeader();
    var m: Image = .{
        .arena = std.heap.ArenaAllocator.init(a),
    };
    while (r.stage != .SeenIEND) {
        try r.parseChunk(&m.arena.allocator);
    }
    m.img = r.img;
    return m;
}
/// Represents a decoded png image. All allocations that are part of the
/// returned image are done on the arena allocator. Call deinit to free up memory
/// when you no longer need the decoded image
pub const Image = struct {
    img: image.Image = undefined,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *Image) void {
        self.arena.deinit();
    }
};
