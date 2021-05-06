const testing = @import("std").testing;
const print = @import("std").debug.print;

/// Color can convert itself to alpha-premultiplied 16-bits per channel RGBA.
/// The conversion may be lossy.
pub const Color = union(enum) {
    rgba: RGBA,
    rgba64: RGBA64,
    nrgba: NRGBA,
    nrgba64: NRGBA64,
    alpha: Alpha,
    alpha16: Alpha16,
    gray: Gray,
    gray16: Gray16,
    yCbCr: YCbCr,
    nYCbCrA: NYCbCrA,
    cMYK: CMYK,

    pub fn toValue(self: Color) Value {
        return switch (self) {
            .rgba => |i| i.toValue(),
            .rgba64 => |i| i.toValue(),
            .nrgba => |i| i.toValue(),
            .nrgba64 => |i| i.toValue(),
            .alpha => |i| i.toValue(),
            .alpha16 => |i| i.toValue(),
            .gray => |i| i.toValue(),
            .gray16 => |i| i.toValue(),
            .yCbCr => |i| i.toValue(),
            .nYCbCrA => |i| i.toValue(),
            .cMYK => |i| i.toValue(),
        };
    }
};

/// Value is the alpha-premultiplied red, green, blue and alpha values
/// for the color. Each value ranges within [0, 0xffff], but is represented
/// by a uint32 so that multiplying by a blend factor up to 0xffff will not
/// overflow.
///
/// An alpha-premultiplied color component c has been scaled by alpha (a),
/// so has valid values 0 <= c <= a.
pub const Value = struct {
    r: u32 = 0,
    g: u32 = 0,
    b: u32 = 0,
    a: u32 = 0,

    pub fn eq(self: Value, n: Value) bool {
        return self.r == n.r and self.g == n.g and self.b == n.b and self.a == n.a;
    }
};

/// Model can convert any Color to one from its own color model. The conversion
/// may be lossy.
pub const Model = struct {
    convert: fn (c: Color) Color,

    pub fn rgbaModel(m: Color) Color {
        return switch (m) {
            .rgba => m,
            else => {
                const c = m.toValue();
                const model = RGBA{
                    .r = @truncate(u8, c.r >> 8),
                    .g = @truncate(u8, c.g >> 8),
                    .b = @truncate(u8, c.b >> 8),
                    .a = @truncate(u8, c.a >> 8),
                };
                return Color{ .rgba = model };
            },
        };
    }

    pub fn rgba64Model(m: Color) Color {
        return switch (m) {
            .rgba64 => m,
            else => {
                const c = m.toValue();
                const model = RGBA64{
                    .r = @truncate(u16, c.r),
                    .g = @truncate(u16, c.g),
                    .b = @truncate(u16, c.b),
                    .a = @truncate(u16, c.a),
                };
                return Color{ .rgba64 = model };
            },
        };
    }

    pub fn nrgbaModel(m: Color) Color {
        return switch (m) {
            .nrgba => m,
            else => {
                const c = m.toValue();
                if (c.a == 0xffff) {
                    const model = NRGBA{
                        .r = @truncate(u8, c.r >> 8),
                        .g = @truncate(u8, c.g >> 8),
                        .b = @truncate(u8, c.b >> 8),
                        .a = 0xff,
                    };
                    return Color{ .nrgba = model };
                }
                if (c.a == 0) {
                    const model = NRGBA{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = 0,
                    };
                    return Color{ .nrgba = model };
                }
                var r = mu(c.r, 0xffff) / c.a;
                var g = mu(c.g, 0xffff) / c.a;
                var b = mu(c.b, 0xffff) / c.a;
                const model = NRGBA{
                    .r = @truncate(u8, r >> 8),
                    .g = @truncate(u8, g >> 8),
                    .b = @truncate(u8, b >> 8),
                    .a = @truncate(u8, c.a >> 8),
                };
                return Color{ .nrgba = model };
            },
        };
    }

    pub fn nrgba64Model(m: Color) Color {
        return switch (m) {
            .nrgba64 => m,
            else => {
                const c = m.toValue();
                if (c.a == 0xffff) {
                    const model = NRGBA64{
                        .r = @truncate(u16, c.r),
                        .g = @truncate(u16, c.g),
                        .b = @truncate(u16, c.b),
                        .a = 0xffff,
                    };
                    return Color{ .nrgba64 = model };
                }
                if (c.a == 0) {
                    const model = NRGBA64{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = 0,
                    };
                    return Color{ .nrgba64 = model };
                }
                var r = mu(c.r, 0xffff) / c.a;
                var g = mu(c.g, 0xffff) / c.a;
                var b = mu(c.b, 0xffff) / c.a;
                const model = NRGBA64{
                    .r = @truncate(u16, r),
                    .g = @truncate(u16, g),
                    .b = @truncate(u16, b),
                    .a = @truncate(u16, c.a),
                };
                return Color{ .nrgba64 = model };
            },
        };
    }

    fn mu(a: u32, b: u32) u32 {
        var r: u32 = undefined;
        _ = @mulWithOverflow(u32, a, b, &r);
        return r;
    }

    pub fn alphaModel(m: Color) Color {
        return switch (m) {
            .alpha => m,
            else => {
                const c = m.toValue();
                const model = Alpha{ .a = @intCast(u8, c.a >> 8) };
                return Color{ .alpha = model };
            },
        };
    }

    pub fn alpha16Model(m: Color) Color {
        return switch (m) {
            .alpha16 => m,
            else => {
                const c = m.toValue();
                const model = Alpha16{ .a = @intCast(u16, c.a) };
                return Color{ .alpha16 = model };
            },
        };
    }

    pub fn grayModel(m: Color) Color {
        return switch (m) {
            .gray => m,
            else => {
                const c = m.toValue();
                // These coefficients (the fractions 0.299, 0.587 and 0.114) are the same
                // as those given by the JFIF specification and used by func RGBToYCbCr in
                // ycbcr.go.
                //
                // Note that 19595 + 38470 + 7471 equals 65536.
                //
                // The 24 is 16 + 8. The 16 is the same as used in RGBToYCbCr. The 8 is
                // because the return value is 8 bit color, not 16 bit color.
                const y = (19595 * c.r + 38470 * c.g + 7471 * c.b + 1 << 15) >> 24;
                const model = Gray{ .y = @intCast(u8, y) };
                return Color{ .gray = model };
            },
        };
    }

    pub fn gray16Model(m: Color) Color {
        return switch (m) {
            .gray16 => m,
            else => {
                const c = m.toValue();
                // These coefficients (the fractions 0.299, 0.587 and 0.114) are the same
                // as those given by the JFIF specification and used by func RGBToYCbCr in
                // ycbcr.go.
                //
                // Note that 19595 + 38470 + 7471 equals 65536.
                const y = (19595 * c.r + 38470 * c.g + 7471 * c.b + 1 << 15) >> 16;
                const model = Gray16{ .y = @intCast(u16, y) };
                return Color{ .gray16 = model };
            },
        };
    }

    pub fn yCbCrModel(m: Color) Color {
        return switch (m) {
            .yCbCr => m,
            else => {
                const v = m.toValue();
                return Color{
                    .yCbCr = rgbToYCbCr(
                        @intCast(u8, v.r >> 8),
                        @intCast(u8, v.g >> 8),
                        @intCast(u8, v.b >> 8),
                    ),
                };
            },
        };
    }

    pub fn nYCbCrAModel(m: Color) Color {
        return switch (m) {
            .yYCbCrA => m,
            .yCbCr => |c| NYCbCrA{
                .y = c,
                .a = 0xff,
            },
            else => {
                var v = m.toValue();
                if (v.a != 0) {
                    v.r = @divTrunc(v.r * 0xffff, v.a);
                    v.g = @divTrunc(v.g * 0xffff, v.a);
                    v.b = @divTrunc(v.b * 0xffff, v.a);
                }
                const y = rgbToYCbCr(
                    @intCast(u8, v.r >> 8),
                    @intCast(u8, v.g >> 8),
                    @intCast(u8, v.b >> 8),
                );
            },
        };
    }
};

/// RGBA represents a traditional 32-bit alpha-premultiplied color, having 8
/// bits for each of red, green, blue and alpha.
///
/// An alpha-premultiplied color component C has been scaled by alpha (A), so
/// has valid values 0 <= C <= A.
pub const RGBA = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,

    fn toValue(c: RGBA) Value {
        var r: u32 = c.r;
        r |= r << 8;
        var g: u32 = c.g;
        g |= g << 8;
        var b: u32 = c.b;
        b |= b << 8;
        var a: u32 = c.a;
        a |= a << 8;
        return Value{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

/// RGBA64 represents a 64-bit alpha-premultiplied color, having 16 bits for
/// each of red, green, blue and alpha.
/// An alpha-premultiplied color component C has been scaled by alpha (A), so
/// has valid values 0 <= C <= A.
pub const RGBA64 = struct {
    r: u16,
    g: u16,
    b: u16,
    a: u16,

    fn toValue(c: RGBA64) Value {
        return Value{
            .r = c.r,
            .g = c.g,
            .b = c.b,
            .a = c.a,
        };
    }
};

/// NRGBA represents a non-alpha-premultiplied 32-bit color.
pub const NRGBA = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    fn toValue(c: NRGBA) Value {
        var r: u32 = c.r;
        var g: u32 = c.g;
        var b: u32 = c.b;
        var a: u32 = c.a;
        r |= r << 8;
        r *= a;
        r /= 0xff;
        g |= g << 8;
        g *= a;
        g /= 0xff;
        b |= b << 8;
        b *= a;
        b /= 0xff;
        a |= a << 8;
        return Value{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

pub const NRGBA64 = struct {
    r: u16,
    g: u16,
    b: u16,
    a: u16,

    fn toValue(c: NRGBA64) Value {
        var r = @intCast(u32, c.r);
        var g = @intCast(u32, c.g);
        var b = @intCast(u32, c.b);
        var a = @intCast(u32, c.a);
        _ = @mulWithOverflow(u32, r, a, &r);
        r /= 0xffff;
        _ = @mulWithOverflow(u32, g, a, &g);
        g /= 0xffff;
        _ = @mulWithOverflow(u32, b, a, &b);
        b /= 0xffff;
        return Value{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }
};

/// Alpha represents an 8-bit alpha color.
pub const Alpha = struct {
    a: u8,

    fn toValue(c: Alpha) Value {
        var a: u32 = c.a;
        a |= a << 8;
        return Value{
            .r = a,
            .g = a,
            .b = a,
            .a = a,
        };
    }
};

pub const Alpha16 = struct {
    a: u16,

    fn toValue(c: Alpha16) Value {
        return Value{
            .r = c.a,
            .g = c.a,
            .b = c.a,
            .a = c.a,
        };
    }
};

/// Gray represents an 8-bit grayscale color.
pub const Gray = struct {
    y: u8,

    fn toValue(c: Gray) Value {
        var y: u32 = c.y;
        y |= y << 8;
        return Value{
            .r = y,
            .g = y,
            .b = y,
            .a = 0xffff,
        };
    }
};

pub const Gray16 = struct {
    y: u16,

    fn toValue(c: Gray16) Value {
        var y: u32 = c.y;
        return Value{
            .r = y,
            .g = y,
            .b = y,
            .a = 0xffff,
        };
    }
};

pub const RGBAModel = Model{ .convert = Model.rgbaModel };
pub const RGBA64Model = Model{ .convert = Model.rgba64Model };
pub const NRGBAModel = Model{ .convert = Model.nrgbaModel };
pub const NRGBA64Model = Model{ .convert = Model.nrgba64Model };
pub const AlphaModel = Model{ .convert = Model.alphaModel };
pub const Alpha16Model = Model{ .convert = Model.alpha16Model };
pub const GrayModel = Model{ .convert = Model.grayModel };
pub const Gray16Model = Model{ .convert = Model.gray16Model };
pub const YCbCrModel = Model{ .convert = Model.yCbCrModel };
pub const NYCbCrAModel = Model{ .convert = Model.nYCbCrAModel };

pub const Black = Color{ .gray = Gray{ .y = 0 } };
pub const White = Color{ .gray = Gray{ .y = 0xffff } };
pub const Transparent = Color{ .alpha = Alpha{ .a = 0 } };
pub const Opaque = Color{ .alpha16 = Alpha16{ .a = 0xffff } };

/// sqDiff returns the squared-difference of x and y, shifted by 2 so that
/// adding four of those won't overflow a uint32.
///
/// x and y are both assumed to be in the range [0, 0xffff].
fn sqDiff(x: u32, y: u32) u32 {
    var d: u32 = 0;
    if (x > y) {
        d = x - y;
    } else {
        d = y - x;
    }
    var m: u32 = undefined;
    _ = @mulWithOverflow(u32, d, d, &m);
    return m >> 2;
}

test "sqDiff" {
    const Kase = struct {
        x: u32,
        y: u32,
        diff: u32,
    };
    const kases = [_]Kase{
        .{ .x = 0x0, .y = 0x0, .diff = 0x0 },
        .{ .x = 0x0, .y = 0x1, .diff = 0x0 },
        .{ .x = 0x0, .y = 0x2, .diff = 0x1 },
        .{ .x = 0x0, .y = 0xfffd, .diff = 0x3ffe8002 },
        .{ .x = 0x0, .y = 0xfffe, .diff = 0x3fff0001 },
        .{ .x = 0x0, .y = 0xffff, .diff = 0x3fff8000 },
        .{ .x = 0x0, .y = 0x10000, .diff = 0x0 },
        .{ .x = 0x0, .y = 0x10001, .diff = 0x8000 },
        .{ .x = 0x0, .y = 0x10002, .diff = 0x10001 },
        .{ .x = 0x0, .y = 0xfffffffd, .diff = 0x2 },
        .{ .x = 0x0, .y = 0xfffffffe, .diff = 0x1 },
        .{ .x = 0x0, .y = 0xffffffff, .diff = 0x0 },
        .{ .x = 0x1, .y = 0x0, .diff = 0x0 },
        .{ .x = 0x1, .y = 0x1, .diff = 0x0 },
        .{ .x = 0x1, .y = 0x2, .diff = 0x0 },
        .{ .x = 0x1, .y = 0xfffd, .diff = 0x3ffe0004 },
        .{ .x = 0x1, .y = 0xfffe, .diff = 0x3ffe8002 },
        .{ .x = 0x1, .y = 0xffff, .diff = 0x3fff0001 },
        .{ .x = 0x1, .y = 0x10000, .diff = 0x3fff8000 },
        .{ .x = 0x1, .y = 0x10001, .diff = 0x0 },
        .{ .x = 0x1, .y = 0x10002, .diff = 0x8000 },
        .{ .x = 0x1, .y = 0xfffffffd, .diff = 0x4 },
        .{ .x = 0x1, .y = 0xfffffffe, .diff = 0x2 },
        .{ .x = 0x1, .y = 0xffffffff, .diff = 0x1 },
        .{ .x = 0x2, .y = 0x0, .diff = 0x1 },
        .{ .x = 0x2, .y = 0x1, .diff = 0x0 },
        .{ .x = 0x2, .y = 0x2, .diff = 0x0 },
        .{ .x = 0x2, .y = 0xfffd, .diff = 0x3ffd8006 },
        .{ .x = 0x2, .y = 0xfffe, .diff = 0x3ffe0004 },
        .{ .x = 0x2, .y = 0xffff, .diff = 0x3ffe8002 },
        .{ .x = 0x2, .y = 0x10000, .diff = 0x3fff0001 },
        .{ .x = 0x2, .y = 0x10001, .diff = 0x3fff8000 },
        .{ .x = 0x2, .y = 0x10002, .diff = 0x0 },
        .{ .x = 0x2, .y = 0xfffffffd, .diff = 0x6 },
        .{ .x = 0x2, .y = 0xfffffffe, .diff = 0x4 },
        .{ .x = 0x2, .y = 0xffffffff, .diff = 0x2 },
        .{ .x = 0xfffd, .y = 0x0, .diff = 0x3ffe8002 },
        .{ .x = 0xfffd, .y = 0x1, .diff = 0x3ffe0004 },
        .{ .x = 0xfffd, .y = 0x2, .diff = 0x3ffd8006 },
        .{ .x = 0xfffd, .y = 0xfffd, .diff = 0x0 },
        .{ .x = 0xfffd, .y = 0xfffe, .diff = 0x0 },
        .{ .x = 0xfffd, .y = 0xffff, .diff = 0x1 },
        .{ .x = 0xfffd, .y = 0x10000, .diff = 0x2 },
        .{ .x = 0xfffd, .y = 0x10001, .diff = 0x4 },
        .{ .x = 0xfffd, .y = 0x10002, .diff = 0x6 },
        .{ .x = 0xfffd, .y = 0xfffffffd, .diff = 0x0 },
        .{ .x = 0xfffd, .y = 0xfffffffe, .diff = 0x3fff8000 },
        .{ .x = 0xfffd, .y = 0xffffffff, .diff = 0x3fff0001 },
        .{ .x = 0xfffe, .y = 0x0, .diff = 0x3fff0001 },
        .{ .x = 0xfffe, .y = 0x1, .diff = 0x3ffe8002 },
        .{ .x = 0xfffe, .y = 0x2, .diff = 0x3ffe0004 },
        .{ .x = 0xfffe, .y = 0xfffd, .diff = 0x0 },
        .{ .x = 0xfffe, .y = 0xfffe, .diff = 0x0 },
        .{ .x = 0xfffe, .y = 0xffff, .diff = 0x0 },
        .{ .x = 0xfffe, .y = 0x10000, .diff = 0x1 },
        .{ .x = 0xfffe, .y = 0x10001, .diff = 0x2 },
        .{ .x = 0xfffe, .y = 0x10002, .diff = 0x4 },
        .{ .x = 0xfffe, .y = 0xfffffffd, .diff = 0x8000 },
        .{ .x = 0xfffe, .y = 0xfffffffe, .diff = 0x0 },
        .{ .x = 0xfffe, .y = 0xffffffff, .diff = 0x3fff8000 },
        .{ .x = 0xffff, .y = 0x0, .diff = 0x3fff8000 },
        .{ .x = 0xffff, .y = 0x1, .diff = 0x3fff0001 },
        .{ .x = 0xffff, .y = 0x2, .diff = 0x3ffe8002 },
        .{ .x = 0xffff, .y = 0xfffd, .diff = 0x1 },
        .{ .x = 0xffff, .y = 0xfffe, .diff = 0x0 },
        .{ .x = 0xffff, .y = 0xffff, .diff = 0x0 },
        .{ .x = 0xffff, .y = 0x10000, .diff = 0x0 },
        .{ .x = 0xffff, .y = 0x10001, .diff = 0x1 },
        .{ .x = 0xffff, .y = 0x10002, .diff = 0x2 },
        .{ .x = 0xffff, .y = 0xfffffffd, .diff = 0x10001 },
        .{ .x = 0xffff, .y = 0xfffffffe, .diff = 0x8000 },
        .{ .x = 0xffff, .y = 0xffffffff, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x0, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x1, .diff = 0x3fff8000 },
        .{ .x = 0x10000, .y = 0x2, .diff = 0x3fff0001 },
        .{ .x = 0x10000, .y = 0xfffd, .diff = 0x2 },
        .{ .x = 0x10000, .y = 0xfffe, .diff = 0x1 },
        .{ .x = 0x10000, .y = 0xffff, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x10000, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x10001, .diff = 0x0 },
        .{ .x = 0x10000, .y = 0x10002, .diff = 0x1 },
        .{ .x = 0x10000, .y = 0xfffffffd, .diff = 0x18002 },
        .{ .x = 0x10000, .y = 0xfffffffe, .diff = 0x10001 },
        .{ .x = 0x10000, .y = 0xffffffff, .diff = 0x8000 },
        .{ .x = 0x10001, .y = 0x0, .diff = 0x8000 },
        .{ .x = 0x10001, .y = 0x1, .diff = 0x0 },
        .{ .x = 0x10001, .y = 0x2, .diff = 0x3fff8000 },
        .{ .x = 0x10001, .y = 0xfffd, .diff = 0x4 },
        .{ .x = 0x10001, .y = 0xfffe, .diff = 0x2 },
        .{ .x = 0x10001, .y = 0xffff, .diff = 0x1 },
        .{ .x = 0x10001, .y = 0x10000, .diff = 0x0 },
        .{ .x = 0x10001, .y = 0x10001, .diff = 0x0 },
        .{ .x = 0x10001, .y = 0x10002, .diff = 0x0 },
        .{ .x = 0x10001, .y = 0xfffffffd, .diff = 0x20004 },
        .{ .x = 0x10001, .y = 0xfffffffe, .diff = 0x18002 },
        .{ .x = 0x10001, .y = 0xffffffff, .diff = 0x10001 },
        .{ .x = 0x10002, .y = 0x0, .diff = 0x10001 },
        .{ .x = 0x10002, .y = 0x1, .diff = 0x8000 },
        .{ .x = 0x10002, .y = 0x2, .diff = 0x0 },
        .{ .x = 0x10002, .y = 0xfffd, .diff = 0x6 },
        .{ .x = 0x10002, .y = 0xfffe, .diff = 0x4 },
        .{ .x = 0x10002, .y = 0xffff, .diff = 0x2 },
        .{ .x = 0x10002, .y = 0x10000, .diff = 0x1 },
        .{ .x = 0x10002, .y = 0x10001, .diff = 0x0 },
        .{ .x = 0x10002, .y = 0x10002, .diff = 0x0 },
        .{ .x = 0x10002, .y = 0xfffffffd, .diff = 0x28006 },
        .{ .x = 0x10002, .y = 0xfffffffe, .diff = 0x20004 },
        .{ .x = 0x10002, .y = 0xffffffff, .diff = 0x18002 },
        .{ .x = 0xfffffffd, .y = 0x0, .diff = 0x2 },
        .{ .x = 0xfffffffd, .y = 0x1, .diff = 0x4 },
        .{ .x = 0xfffffffd, .y = 0x2, .diff = 0x6 },
        .{ .x = 0xfffffffd, .y = 0xfffd, .diff = 0x0 },
        .{ .x = 0xfffffffd, .y = 0xfffe, .diff = 0x8000 },
        .{ .x = 0xfffffffd, .y = 0xffff, .diff = 0x10001 },
        .{ .x = 0xfffffffd, .y = 0x10000, .diff = 0x18002 },
        .{ .x = 0xfffffffd, .y = 0x10001, .diff = 0x20004 },
        .{ .x = 0xfffffffd, .y = 0x10002, .diff = 0x28006 },
        .{ .x = 0xfffffffd, .y = 0xfffffffd, .diff = 0x0 },
        .{ .x = 0xfffffffd, .y = 0xfffffffe, .diff = 0x0 },
        .{ .x = 0xfffffffd, .y = 0xffffffff, .diff = 0x1 },
        .{ .x = 0xfffffffe, .y = 0x0, .diff = 0x1 },
        .{ .x = 0xfffffffe, .y = 0x1, .diff = 0x2 },
        .{ .x = 0xfffffffe, .y = 0x2, .diff = 0x4 },
        .{ .x = 0xfffffffe, .y = 0xfffd, .diff = 0x3fff8000 },
        .{ .x = 0xfffffffe, .y = 0xfffe, .diff = 0x0 },
        .{ .x = 0xfffffffe, .y = 0xffff, .diff = 0x8000 },
        .{ .x = 0xfffffffe, .y = 0x10000, .diff = 0x10001 },
        .{ .x = 0xfffffffe, .y = 0x10001, .diff = 0x18002 },
        .{ .x = 0xfffffffe, .y = 0x10002, .diff = 0x20004 },
        .{ .x = 0xfffffffe, .y = 0xfffffffd, .diff = 0x0 },
        .{ .x = 0xfffffffe, .y = 0xfffffffe, .diff = 0x0 },
        .{ .x = 0xfffffffe, .y = 0xffffffff, .diff = 0x0 },
        .{ .x = 0xffffffff, .y = 0x0, .diff = 0x0 },
        .{ .x = 0xffffffff, .y = 0x1, .diff = 0x1 },
        .{ .x = 0xffffffff, .y = 0x2, .diff = 0x2 },
        .{ .x = 0xffffffff, .y = 0xfffd, .diff = 0x3fff0001 },
        .{ .x = 0xffffffff, .y = 0xfffe, .diff = 0x3fff8000 },
        .{ .x = 0xffffffff, .y = 0xffff, .diff = 0x0 },
        .{ .x = 0xffffffff, .y = 0x10000, .diff = 0x8000 },
        .{ .x = 0xffffffff, .y = 0x10001, .diff = 0x10001 },
        .{ .x = 0xffffffff, .y = 0x10002, .diff = 0x18002 },
        .{ .x = 0xffffffff, .y = 0xfffffffd, .diff = 0x1 },
        .{ .x = 0xffffffff, .y = 0xfffffffe, .diff = 0x0 },
        .{ .x = 0xffffffff, .y = 0xffffffff, .diff = 0x0 },
    };
    for (kases) |v| {
        const got = sqDiff(v.x, v.y);
        testing.expectEqual(v.diff, got);
    }
}

fn short01(v: i32) i32 {
    if (@bitCast(u32, v) & 0xff000000 == 0) {
        return v >> 16;
    }
    return ~(v >> 31);
}

fn short02(v: i32) i32 {
    if (@bitCast(u32, v) & 0xff000000 == 0) {
        return v >> 16;
    }
    return ~(v >> 31) & 0xffff;
}

fn short8(v: i32) i32 {
    if (@bitCast(u32, v) & 0xff000000 == 0) {
        return v >> 8;
    }
    return ~(v >> 31) & 0xffff;
}

// rgbToYCbCr converts an RGB triple to a Y'CbCr triple.
pub fn rgbToYCbCr(c: RGB) YCbCr {
    const r1 = @intCast(i32, c.r);
    const g1 = @intCast(i32, c.g);
    const b1 = @intCast(i32, c.b);
    const yy = (19595 * r1 + 38470 * g1 + 7471 * b1 + (1 << 15)) >> 16;
    const cb = short01(-11056 * r1 - 21712 * g1 + 32768 * b1 + (257 << 15));
    const cr = short01(32768 * r1 - 27440 * g1 - 5328 * b1 + (257 << 15));
    return YCbCr{
        .y = @truncate(u8, @bitCast(u32, yy)),
        .cr = @truncate(u8, @bitCast(u32, cr)),
        .cb = @truncate(u8, @bitCast(u32, cb)),
    };
}

pub const RGB = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub fn yCbCrToRGB(c: YCbCr) RGB {
    const yy1 = @intCast(i32, c.y) * 0x10101;
    const cb1 = @intCast(i32, c.cb) - 128;
    const cr1 = @intCast(i32, c.cr) - 128;

    const r = short02(yy1 + 91881 * cr1);
    const g = short02(yy1 - 22554 * cb1 - 46802 * cr1);
    const b = short02(yy1 + 116130 * cb1);

    return RGB{
        .r = @truncate(u8, @bitCast(u32, r)),
        .g = @truncate(u8, @bitCast(u32, g)),
        .b = @truncate(u8, @bitCast(u32, b)),
    };
}

test "TestYCbCrRoundtrip" {
    var r: usize = 0;
    while (r < 256) : (r += 7) {
        var g: usize = 0;
        while (g < 256) : (g += 5) {
            var b: usize = 0;
            while (b < 256) : (b += 3) {
                const o = RGB{
                    .r = @truncate(u8, r),
                    .g = @truncate(u8, g),
                    .b = @truncate(u8, b),
                };
                const v0 = rgbToYCbCr(o);
                const v1 = yCbCrToRGB(v0);
                if (ytest.delta(o.r, v1.r) > 2 or
                    ytest.delta(o.g, v1.g) > 2 or
                    ytest.delta(o.b, v1.b) > 2)
                {
                    print("{any} {any} {any}", .{ v0, o, v1 });
                    testing.expectEqual(o, v1);
                }
            }
        }
    }
}

test "TestYCbCrToRGBConsistency" {
    // TestYCbCrToRGBConsistency tests that calling the RGBA method (16 bit color)
    // then truncating to 8 bits is equivalent to calling the YCbCrToRGB function (8
    // bit color).

    var y: usize = 0;
    while (y < 256) : (y += 7) {
        var cb: usize = 0;
        while (cb < 256) : (cb += 5) {
            var cr: usize = 0;
            while (cr < 256) : (cr += 3) {
                const o = YCbCr{
                    .y = @truncate(u8, y),
                    .cb = @truncate(u8, cb),
                    .cr = @truncate(u8, cr),
                };
                const v0 = o.toValue();
                const v1 = RGB{
                    .r = @truncate(u8, v0.r >> 8),
                    .g = @truncate(u8, v0.g >> 8),
                    .b = @truncate(u8, v0.b >> 8),
                };
                const v2 = yCbCrToRGB(o);
                // print("{any} {any} {any}", .{ v0, v1, v2 });
                testing.expectEqual(v1, v2);
            }
        }
    }
}

test "TestYCbCrGray" {
    // TestYCbCrGray tests that YCbCr colors are a superset of Gray colors.
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const c0 = Color{
            .yCbCr = YCbCr{
                .y = @intCast(u8, i),
                .cb = 0x80,
                .cr = 0x80,
            },
        };
        const c1 = Color{
            .gray = Gray{
                .y = @intCast(u8, i),
            },
        };
        ytest.eq(c0, c1);
    }
}

test "TestNYCbCrAAlpha" {
    // TestNYCbCrAAlpha tests that NYCbCrA colors are a superset of Alpha colors.
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const c0 = Color{
            .nYCbCrA = NYCbCrA{
                .y = YCbCr{
                    .y = 0xff,
                    .cb = 0x80,
                    .cr = 0x80,
                },
                .a = @intCast(u8, i),
            },
        };
        const c1 = Color{
            .alpha = Alpha{
                .a = @intCast(u8, i),
            },
        };
        ytest.eq(c0, c1);
    }
}

test "TestNYCbCrAYCbCr" {
    // TestNYCbCrAYCbCr tests that NYCbCrA colors are a superset of YCbCr colors.
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const c0 = Color{
            .nYCbCrA = NYCbCrA{
                .y = YCbCr{
                    .y = @intCast(u8, i),
                    .cb = 0x40,
                    .cr = 0xc0,
                },
                .a = 0xff,
            },
        };
        const c1 = Color{
            .yCbCr = YCbCr{
                .y = @intCast(u8, i),
                .cb = 0x40,
                .cr = 0xc0,
            },
        };
        ytest.eq(c0, c1);
    }
}

// YCbCr represents a fully opaque 24-bit Y'CbCr color, having 8 bits each for
// one luma and two chroma components.
//
// JPEG, VP8, the MPEG family and other codecs use this color model. Such
// codecs often use the terms YUV and Y'CbCr interchangeably, but strictly
// speaking, the term YUV applies only to analog video signals, and Y' (luma)
// is Y (luminance) after applying gamma correction.
//
// Conversion between RGB and Y'CbCr is lossy and there are multiple, slightly
// different formulae for converting between the two. This package follows
// the JFIF specification at https://www.w3.org/Graphics/JPEG/jfif3.pdf.
const YCbCr = struct {
    y: u8,
    cb: u8,
    cr: u8,

    pub fn toValue(self: YCbCr) Value {
        const yy1 = @intCast(i32, self.y) * 0x10101;
        const cb1 = @intCast(i32, self.cb) - 128;
        const cr1 = @intCast(i32, self.cr) - 128;

        const r = short8(yy1 + 91881 * cr1);
        const g = short8(yy1 - 22554 * cb1 - 46802 * cr1);
        const b = short8(yy1 + 116130 * cb1);
        return Value{
            .r = @intCast(u32, r),
            .g = @intCast(u32, g),
            .b = @intCast(u32, b),
            .a = 0xffff,
        };
    }
};

const NYCbCrA = struct {
    y: YCbCr,
    a: u8,

    pub fn toValue(self: NYCbCrA) Value {
        var yy1 = @intCast(i32, self.y.y) * 0x10101;
        var cb1 = @intCast(i32, self.y.cb) - 128;
        var cr1 = @intCast(i32, self.y.cr) - 128;

        const r = short8(yy1 + 91881 * cr1);
        const g = short8(yy1 - 22554 * cb1 - 46802 * cr1);
        const b = short8(yy1 + 116130 * cb1);
        const a = @intCast(u32, self.a) * 0x101;
        return Value{
            .r = @divTrunc(@bitCast(u32, r) * a, 0xffff),
            .g = @divTrunc(@bitCast(u32, g) * a, 0xffff),
            .b = @divTrunc(@bitCast(u32, b) * a, 0xffff),
            .a = a,
        };
    }
};

const Palette = struct {
    colors: []Color,

    pub fn convert(self: Palette, c: Color) ?Color {
        if (self.colors.len == 0) {
            return null;
        }
        return self.colors[self.index(c)];
    }

    pub fn index(self: Palette, c: Color) usize {
        const value = c.toValue();
        var ret: u32 = 0;
        var best_sum: u32 = (1 << 32) - 1;
        for (self.colors) |v, i| {
            const value2 = v.toValue();
            const sum = sqDiff(value.r, value2.r) +
                sqDiff(value.g, value2.g) +
                sqDiff(value.b, value2.b) +
                sqDiff(value.a, value2.a);
            if (sum < best_sum) {
                if (sum == 0) {
                    return i;
                }
                ret = i;
                best_sum = sum;
            }
        }
        return ret;
    }
};

const ytest = struct {
    fn delta(x: u8, y: u8) u8 {
        if (x >= y) {
            return x - y;
        }
        return y - x;
    }

    fn eq(c0: Color, c1: Color) void {
        testing.expectEqual(c0.toValue(), c1.toValue());
    }
};

pub fn rgbToCMYK(a: RGB) CMYK {
    const rr = @intCast(u32, a.r);
    const gg = @intCast(u32, a.g);
    const bb = @intCast(u32, a.b);
    var w = rr;
    if (w < gg) {
        w = gg;
    }
    if (w < bb) {
        w = bb;
    }
    if (w == 0) {
        return CMYK{
            .c = 0,
            .m = 0,
            .y = 0,
            .k = 0xff,
        };
    }
    const c = ((w - rr) * 0xff) / w;
    const m = ((w - gg) * 0xff) / w;
    const y = ((w - bb) * 0xff) / w;
    return CMYK{
        .c = @truncate(u8, c),
        .m = @truncate(u8, m),
        .y = @truncate(u8, y),
        .k = @truncate(u8, 0xff - w),
    };
}

pub fn cmykToRGB(a: CMYK) RGB {
    const w = 0xffff - @intCast(u32, a.k) * 0x101;
    const r = ((0xffff - @intCast(u32, a.c) * 0x101) * w) / 0xffff;
    const g = ((0xffff - @intCast(u32, a.m) * 0x101) * w) / 0xffff;
    const b = ((0xffff - @intCast(u32, a.y) * 0x101) * w) / 0xffff;
    return RGB{
        .r = @truncate(u8, r >> 8),
        .g = @truncate(u8, g >> 8),
        .b = @truncate(u8, b >> 8),
    };
}

pub const CMYK = struct {
    c: u8,
    m: u8,
    y: u8,
    k: u8,

    pub fn toValue(self: CMYK) Value {
        const w = 0xffff - @intCast(u32, self.k) * 0x101;
        const r = ((0xffff - @intCast(u32, self.c) * 0x101) * w) / 0xffff;
        const g = ((0xffff - @intCast(u32, self.m) * 0x101) * w) / 0xffff;
        const b = ((0xffff - @intCast(u32, self.y) * 0x101) * w) / 0xffff;
        return Value{
            .r = r,
            .g = g,
            .b = b,
            .a = 0xffff,
        };
    }
};

test "TestCMYKRoundtrip" {
    var r: usize = 0;
    while (r < 256) : (r += 7) {
        var g: usize = 0;
        while (g < 256) : (g += 5) {
            var b: usize = 0;
            while (b < 256) : (b += 3) {
                const v0 = RGB{
                    .r = @intCast(u8, r),
                    .g = @intCast(u8, g),
                    .b = @intCast(u8, b),
                };
                const v1 = rgbToCMYK(v0);
                const v2 = cmykToRGB(v1);
                if (ytest.delta(v0.r, v2.r) > 1 or
                    ytest.delta(v0.g, v2.g) > 1 or
                    ytest.delta(v0.g, v2.g) > 1)
                {
                    testing.expectEqual(v0, v2);
                }
            }
        }
    }
}
